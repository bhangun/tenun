// Chart export utilities — PNG, JPEG, SVG, CSV, and XLSX.
//
// Export any chart widget to:
//   - [ChartExporter.toPng] — raw PNG bytes via [RenderRepaintBoundary]
//   - [ChartExporter.toJpeg] — JPEG bytes via raw capture + encoder
//   - [ChartExporter.toCsv] — tabular CSV string from series data
//   - [ChartExporter.toXlsx] — dependency-free workbook bytes
//   - [SvgChartExporter] — basic SVG export for line/bar/pie charts
//
// Usage:
// ```dart
// // 1. Wrap chart in a GlobalKey-ed RepaintBoundary (or use ExportableChart):
// final _exportKey = GlobalKey();
//
// RepaintBoundary(
//   key: _exportKey,
//   child: TenunChart(config: myConfig),
// )
//
// // 2. Export:
// final bytes = await ChartExporter.toPng(_exportKey);
// final jpeg = await ChartExporter.toJpeg(_exportKey, quality: 90);
// // then save bytes with path_provider or share with share_plus
//
// // CSV:
// final csv = ChartExporter.toCsv(myConfig);
//
// // XLSX:
// final xlsxBytes = ChartExporter.toXlsx(myConfig);
// ```

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import 'base_config.dart';
import 'chart_export_capability.dart';
import 'chart_export_format.dart';
import 'chart_export_filename.dart';
import 'chart_zip_store_writer.dart';

export 'chart_export_format.dart';

enum ChartImageExportFormat { png, jpeg }

typedef ChartExportBatchProgressHandler =
    void Function(ChartExportBatchProgress progress);
typedef ChartExportBatchProgressErrorHandler =
    void Function(
      Object error,
      StackTrace stackTrace,
      ChartExportBatchProgress progress,
    );

class ChartExportCancellationToken {
  ChartExportCancellationToken();

  final Completer<void> _completer = Completer<void>();
  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;

  String? get reason => _reason;

  Future<void> get whenCancelled => _completer.future;

  void cancel([String reason = 'Operation cancelled.']) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    _completer.complete();
  }
}

class ChartExportRequest {
  final ChartExportFormat format;
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
  final Duration? timeout;
  final ChartExportCancellationToken? cancellationToken;

  const ChartExportRequest({
    required this.format,
    this.config,
    this.jsonConfig,
    this.rows,
    this.boundaryKey,
    this.categoryLabels,
    this.filename,
    this.sheetName = 'Chart Data',
    this.delimiter = ',',
    this.lineEnding = '\r\n',
    this.pixelRatio = 2.0,
    this.jpegQuality = 90,
    this.jpegBackgroundColor = Colors.white,
    this.timeout,
    this.cancellationToken,
  });

  const ChartExportRequest.csv({
    required BaseChartConfig this.config,
    this.jsonConfig,
    this.rows,
    this.categoryLabels,
    this.filename,
    this.delimiter = ',',
    this.lineEnding = '\r\n',
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.csv,
       boundaryKey = null,
       sheetName = 'Chart Data',
       pixelRatio = 2.0,
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  const ChartExportRequest.xlsx({
    required BaseChartConfig this.config,
    this.jsonConfig,
    this.rows,
    this.categoryLabels,
    this.filename,
    this.sheetName = 'Chart Data',
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.xlsx,
       boundaryKey = null,
       delimiter = ',',
       lineEnding = '\r\n',
       pixelRatio = 2.0,
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  const ChartExportRequest.png({
    required GlobalKey this.boundaryKey,
    this.filename,
    this.pixelRatio = 2.0,
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.png,
       config = null,
       jsonConfig = null,
       rows = null,
       categoryLabels = null,
       sheetName = 'Chart Data',
       delimiter = ',',
       lineEnding = '\r\n',
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  const ChartExportRequest.jpeg({
    required GlobalKey this.boundaryKey,
    this.filename,
    this.pixelRatio = 2.0,
    this.jpegQuality = 90,
    this.jpegBackgroundColor = Colors.white,
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.jpeg,
       config = null,
       jsonConfig = null,
       rows = null,
       categoryLabels = null,
       sheetName = 'Chart Data',
       delimiter = ',',
       lineEnding = '\r\n';

  const ChartExportRequest.csvPayload({
    required Map<String, dynamic> this.jsonConfig,
    this.categoryLabels,
    this.filename,
    this.delimiter = ',',
    this.lineEnding = '\r\n',
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.csv,
       config = null,
       rows = null,
       boundaryKey = null,
       sheetName = 'Chart Data',
       pixelRatio = 2.0,
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  const ChartExportRequest.xlsxPayload({
    required Map<String, dynamic> this.jsonConfig,
    this.categoryLabels,
    this.filename,
    this.sheetName = 'Chart Data',
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.xlsx,
       config = null,
       rows = null,
       boundaryKey = null,
       delimiter = ',',
       lineEnding = '\r\n',
       pixelRatio = 2.0,
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  const ChartExportRequest.csvRows({
    required List<List<Object?>> this.rows,
    this.filename,
    this.delimiter = ',',
    this.lineEnding = '\r\n',
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.csv,
       config = null,
       jsonConfig = null,
       boundaryKey = null,
       categoryLabels = null,
       sheetName = 'Chart Data',
       pixelRatio = 2.0,
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  const ChartExportRequest.xlsxRows({
    required List<List<Object?>> this.rows,
    this.filename,
    this.sheetName = 'Chart Data',
    this.timeout,
    this.cancellationToken,
  }) : format = ChartExportFormat.xlsx,
       config = null,
       jsonConfig = null,
       boundaryKey = null,
       categoryLabels = null,
       delimiter = ',',
       lineEnding = '\r\n',
       pixelRatio = 2.0,
       jpegQuality = 90,
       jpegBackgroundColor = Colors.white;

  String get resolvedFilename {
    return ChartExportFilename.withExtension(
      filename,
      format.extension,
      fallback: ChartExportFilename.defaultFallback,
    );
  }

  ChartExportRequest withBatchControls({
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
  }) {
    if (timeout == null && cancellationToken == null) return this;
    return ChartExportRequest(
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
      timeout: this.timeout ?? timeout,
      cancellationToken: this.cancellationToken ?? cancellationToken,
    );
  }
}

class ChartExportResult {
  final ChartExportFormat format;
  final String mimeType;
  final String filename;
  final Uint8List? bytes;
  final String? text;
  final String? error;
  final Duration? duration;

  const ChartExportResult({
    required this.format,
    required this.mimeType,
    required this.filename,
    this.bytes,
    this.text,
    this.error,
    this.duration,
  });

  factory ChartExportResult.text({
    required ChartExportFormat format,
    required String filename,
    required String text,
    Duration? duration,
  }) {
    return ChartExportResult(
      format: format,
      mimeType: format.mimeType,
      filename: filename,
      text: text,
      duration: duration,
    );
  }

  factory ChartExportResult.bytes({
    required ChartExportFormat format,
    required String filename,
    required Uint8List bytes,
    Duration? duration,
  }) {
    return ChartExportResult(
      format: format,
      mimeType: format.mimeType,
      filename: filename,
      bytes: bytes,
      duration: duration,
    );
  }

  factory ChartExportResult.failure({
    required ChartExportFormat format,
    required String filename,
    required String error,
    Duration? duration,
  }) {
    return ChartExportResult(
      format: format,
      mimeType: format.mimeType,
      filename: filename,
      error: error,
      duration: duration,
    );
  }

  bool get success => error == null;

  bool get isText => text != null;

  bool get isBinary => bytes != null;

  int get sizeBytes => bytes?.length ?? utf8.encode(text ?? '').length;

  Uint8List? get payloadBytes {
    final binary = bytes;
    if (binary != null) return binary;
    final value = text;
    if (value != null) return Uint8List.fromList(utf8.encode(value));
    return null;
  }

  String? get base64Payload {
    final payload = payloadBytes;
    return payload == null ? null : base64Encode(payload);
  }

  String? get dataUri {
    final payload = base64Payload;
    return payload == null ? null : 'data:$mimeType;base64,$payload';
  }

  String contentDisposition({bool attachment = true}) {
    final disposition = attachment ? 'attachment' : 'inline';
    return '$disposition; filename="${_escapeHttpHeaderValue(filename)}"';
  }

  String? textPreview({int maxChars = 160}) {
    final value = text;
    if (value == null) return null;
    if (maxChars <= 0) return '';
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  String? byteSignature({int maxBytes = 12}) {
    final payload = bytes;
    if (payload == null) return null;
    final count = maxBytes <= 0
        ? 0
        : (payload.length < maxBytes ? payload.length : maxBytes);
    return payload
        .take(count)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  String preview({int maxTextChars = 160, int maxBytes = 12}) {
    final failure = error;
    if (failure != null) return failure;

    final textValue = textPreview(maxChars: maxTextChars);
    if (textValue != null) return textValue;

    final signature = byteSignature(maxBytes: maxBytes);
    if (signature != null) {
      return 'bytes=$sizeBytes; signature=$signature';
    }

    return 'empty export payload';
  }

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    final elapsed = duration;
    return {
      'success': success,
      'format': format.name,
      'mimeType': mimeType,
      'filename': filename,
      'sizeBytes': sizeBytes,
      'isText': isText,
      'isBinary': isBinary,
      if (elapsed != null) 'durationMicros': elapsed.inMicroseconds,
      if (elapsed != null) 'durationMs': elapsed.inMicroseconds / 1000,
      if (error != null) 'error': error,
      if (includePayload && text != null) 'text': text,
      if (includePayload && base64Payload != null) 'base64': base64Payload,
    };
  }

  ChartExportResult withDuration(Duration duration) {
    return ChartExportResult(
      format: format,
      mimeType: mimeType,
      filename: filename,
      bytes: bytes,
      text: text,
      error: error,
      duration: duration,
    );
  }

  static String _escapeHttpHeaderValue(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}

class ChartExportBatchResult {
  factory ChartExportBatchResult(
    Iterable<ChartExportResult> results, {
    Iterable<ChartExportCapability> skippedUnavailable = const [],
    int? requestedCount,
  }) {
    final resultList = List<ChartExportResult>.unmodifiable(results);
    final skippedList = List<ChartExportCapability>.unmodifiable(
      skippedUnavailable,
    );
    final minimumRequestedCount = resultList.length + skippedList.length;
    final resolvedRequestedCount =
        requestedCount == null || requestedCount < minimumRequestedCount
        ? minimumRequestedCount
        : requestedCount;
    return ChartExportBatchResult._(
      resultList,
      skippedList,
      resolvedRequestedCount,
    );
  }

  const ChartExportBatchResult._(
    this.results,
    this.skippedUnavailable,
    this.requestedCount,
  );

  final List<ChartExportResult> results;
  final List<ChartExportCapability> skippedUnavailable;
  final int requestedCount;

  bool get success => results.every((result) => result.success);

  bool get hasFailures => results.any((result) => !result.success);

  bool get hasSkippedUnavailable => skippedUnavailable.isNotEmpty;

  bool get hasNotRun => notRunCount > 0;

  bool get hasOutput => outputCount > 0;

  bool get hasIssues => issueCount > 0;

  bool get completedWithoutOutput =>
      requestedCount > 0 && !hasOutput && !hasFailures;

  int get successCount => results.where((result) => result.success).length;

  int get outputCount => successCount;

  int get failureCount => results.length - successCount;

  int get skippedUnavailableCount => skippedUnavailable.length;

  int get notRunCount {
    final count = requestedCount - results.length - skippedUnavailableCount;
    return count < 0 ? 0 : count;
  }

  int get issueCount => failureCount + skippedUnavailableCount + notRunCount;

  int get totalSizeBytes => results.fold<int>(
    0,
    (total, result) => total + (result.success ? result.sizeBytes : 0),
  );

  int get totalDurationMicros => results.fold<int>(
    0,
    (total, result) => total + (result.duration?.inMicroseconds ?? 0),
  );

  List<ChartExportResult> get successful =>
      List.unmodifiable(results.where((result) => result.success));

  List<ChartExportResult> get failed =>
      List.unmodifiable(results.where((result) => !result.success));

  List<String> get issueMessages {
    final messages = <String>[];
    void addIssue(String message) {
      final normalized = message.trim();
      if (normalized.isEmpty || messages.contains(normalized)) return;
      messages.add(normalized);
    }

    for (final result in failed) {
      addIssue(
        'Export failed for ${result.filename}: '
        '${result.error ?? 'Unknown export error.'}',
      );
    }

    for (final skipped in skippedUnavailable) {
      addIssue(
        '${skipped.format.name} export skipped: '
        '${skipped.disabledReason ?? 'Format is unavailable.'}',
      );
    }

    if (notRunCount > 0) {
      addIssue('$notRunCount ${_plural('export', notRunCount)} not run.');
    }

    return List.unmodifiable(messages);
  }

  String? get primaryIssue =>
      issueMessages.isEmpty ? null : issueMessages.first;

  ChartExportResult? resultFor(ChartExportFormat format) {
    for (final result in results) {
      if (result.format == format) return result;
    }
    return null;
  }

  List<ChartExportResult> resultsFor(ChartExportFormat format) {
    return List.unmodifiable(
      results.where((result) => result.format == format),
    );
  }

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    return {
      'success': success,
      'count': results.length,
      'requestedCount': requestedCount,
      'successCount': successCount,
      'outputCount': outputCount,
      'failureCount': failureCount,
      'skippedUnavailableCount': skippedUnavailableCount,
      'notRunCount': notRunCount,
      'issueCount': issueCount,
      'hasOutput': hasOutput,
      'hasIssues': hasIssues,
      'completedWithoutOutput': completedWithoutOutput,
      if (primaryIssue != null) 'primaryIssue': primaryIssue,
      if (issueMessages.isNotEmpty) 'issues': issueMessages,
      'totalSizeBytes': totalSizeBytes,
      if (totalDurationMicros > 0) 'totalDurationMicros': totalDurationMicros,
      if (totalDurationMicros > 0)
        'totalDurationMs': totalDurationMicros / 1000,
      if (skippedUnavailable.isNotEmpty)
        'skippedUnavailable': [
          for (final capability in skippedUnavailable)
            capability.toMetadataJson(),
        ],
      'results': [
        for (final result in results)
          result.toMetadataJson(includePayload: includePayload),
      ],
    };
  }
}

class ChartExportBatchProgress {
  const ChartExportBatchProgress({
    required this.completed,
    required this.total,
    required this.result,
  });

  final int completed;
  final int total;
  final ChartExportResult result;

  int get remaining => total - completed;

  double get fraction => total <= 0 ? 1 : completed / total;

  bool get isComplete => completed >= total;

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    return {
      'completed': completed,
      'total': total,
      'remaining': remaining,
      'fraction': fraction,
      'isComplete': isComplete,
      'result': result.toMetadataJson(includePayload: includePayload),
    };
  }
}

class ChartExportBatchOptions {
  const ChartExportBatchOptions({
    this.stopOnFirstFailure = false,
    this.skipUnavailable = false,
    this.continueOnProgressError = false,
    this.timeout,
    this.cancellationToken,
    this.onProgress,
    this.onProgressError,
  });

  final bool stopOnFirstFailure;
  final bool skipUnavailable;
  final bool continueOnProgressError;
  final Duration? timeout;
  final ChartExportCancellationToken? cancellationToken;
  final ChartExportBatchProgressHandler? onProgress;
  final ChartExportBatchProgressErrorHandler? onProgressError;
}

String _plural(String singular, int count) {
  if (count == 1) return singular;
  return '${singular}s';
}

// ---------------------------------------------------------------------------
// ChartExporter
// ---------------------------------------------------------------------------

class ChartExporter {
  static const String csvMimeType = 'text/csv';
  static const String xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const String pngMimeType = 'image/png';
  static const String jpegMimeType = 'image/jpeg';

  /// Export chart data or pixels through a single request/result API.
  static Future<ChartExportResult> export(ChartExportRequest request) async {
    final stopwatch = Stopwatch()..start();
    final filename = request.resolvedFilename;
    if (request.cancellationToken?.isCancelled == true) {
      return _cancelledExportResult(
        request,
        filename,
      ).withDuration(stopwatch.elapsed);
    }
    final validationError = _validateRequestOptions(request);
    if (validationError != null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: validationError,
        duration: stopwatch.elapsed,
      );
    }
    try {
      final result = await _guardExport(
        () => _performExport(request, filename),
        request,
        filename,
      );
      return result.withDuration(stopwatch.elapsed);
    } catch (error) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: error.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }

  static Future<ChartExportResult> _performExport(
    ChartExportRequest request,
    String filename,
  ) async {
    return switch (request.format) {
      ChartExportFormat.csv => _exportCsv(request, filename),
      ChartExportFormat.xlsx => _exportXlsx(request, filename),
      ChartExportFormat.png => await _exportPng(request, filename),
      ChartExportFormat.jpeg => await _exportJpeg(request, filename),
    };
  }

  static String? _validateRequestOptions(ChartExportRequest request) {
    return switch (request.format) {
      ChartExportFormat.csv when request.delimiter.isEmpty =>
        'CSV export delimiter must not be empty.',
      ChartExportFormat.png when !_isValidPixelRatio(request.pixelRatio) =>
        _imagePixelRatioError('PNG'),
      ChartExportFormat.jpeg when !_isValidPixelRatio(request.pixelRatio) =>
        _imagePixelRatioError('JPEG'),
      _ => null,
    };
  }

  static bool _isValidPixelRatio(double pixelRatio) {
    return pixelRatio.isFinite && pixelRatio > 0;
  }

  static String _imagePixelRatioError(String formatLabel) {
    return '$formatLabel export pixelRatio must be a finite positive number.';
  }

  static Future<ChartExportResult> _guardExport(
    Future<ChartExportResult> Function() operation,
    ChartExportRequest request,
    String filename,
  ) {
    final timeout = request.timeout;
    if (timeout != null && timeout.inMicroseconds <= 0) {
      return Future.value(_timeoutExportResult(request, filename, timeout));
    }

    Future<ChartExportResult> guarded = operation();
    if (timeout != null) {
      guarded = guarded.timeout(
        timeout,
        onTimeout: () => _timeoutExportResult(request, filename, timeout),
      );
    }

    final token = request.cancellationToken;
    if (token == null) return guarded;
    if (token.isCancelled) {
      return Future.value(_cancelledExportResult(request, filename));
    }

    return Future.any([
      guarded,
      token.whenCancelled.then(
        (_) => _cancelledExportResult(request, filename),
      ),
    ]);
  }

  static ChartExportResult _cancelledExportResult(
    ChartExportRequest request,
    String filename,
  ) {
    return ChartExportResult.failure(
      format: request.format,
      filename: filename,
      error: request.cancellationToken?.reason ?? 'Export cancelled.',
    );
  }

  static ChartExportResult _timeoutExportResult(
    ChartExportRequest request,
    String filename,
    Duration timeout,
  ) {
    return ChartExportResult.failure(
      format: request.format,
      filename: filename,
      error: 'Export timed out after ${_formatDuration(timeout)}.',
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inMilliseconds >= 1000) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    if (duration.inMilliseconds > 0) {
      return '${duration.inMilliseconds}ms';
    }
    return '${duration.inMicroseconds}us';
  }

  /// Export several requests and return a single summary object.
  ///
  /// Each request is isolated: one failed export does not prevent later exports
  /// from running, which is important for mixed data + image batches.
  static Future<ChartExportBatchResult> exportAll(
    Iterable<ChartExportRequest> requests, {
    ChartExportBatchOptions options = const ChartExportBatchOptions(),
  }) async {
    final allRequests = List<ChartExportRequest>.unmodifiable(requests);
    final requestList = <ChartExportRequest>[];
    final skippedUnavailable = <ChartExportCapability>[];
    for (final request in allRequests) {
      final capability = capabilityForRequest(request);
      if (options.skipUnavailable && !capability.canExport) {
        skippedUnavailable.add(capability);
      } else {
        requestList.add(request);
      }
    }
    final results = <ChartExportResult>[];
    for (final request in requestList) {
      final result = await export(
        request.withBatchControls(
          timeout: options.timeout,
          cancellationToken: options.cancellationToken,
        ),
      );
      results.add(result);
      _emitBatchProgress(
        options,
        ChartExportBatchProgress(
          completed: results.length,
          total: requestList.length,
          result: result,
        ),
      );
      if (options.stopOnFirstFailure && !result.success) break;
    }
    return ChartExportBatchResult(
      results,
      skippedUnavailable: skippedUnavailable,
      requestedCount: allRequests.length,
    );
  }

  static void _emitBatchProgress(
    ChartExportBatchOptions options,
    ChartExportBatchProgress progress,
  ) {
    final handler = options.onProgress;
    if (handler == null) return;

    try {
      handler(progress);
    } catch (error, stackTrace) {
      _handleBatchProgressError(options, error, stackTrace, progress);
    }
  }

  static void _handleBatchProgressError(
    ChartExportBatchOptions options,
    Object error,
    StackTrace stackTrace,
    ChartExportBatchProgress progress,
  ) {
    final errorHandler = options.onProgressError;
    if (errorHandler != null) {
      try {
        errorHandler(error, stackTrace, progress);
      } catch (handlerError, handlerStackTrace) {
        if (!options.continueOnProgressError) {
          Error.throwWithStackTrace(handlerError, handlerStackTrace);
        }
      }
    }

    if (!options.continueOnProgressError) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Resolve whether one request has enough inputs to run.
  static ChartExportCapability capabilityForRequest(
    ChartExportRequest request,
  ) {
    final validationError = _validateRequestOptions(request);
    if (validationError != null) {
      return ChartExportCapability.unavailable(request.format, validationError);
    }

    return ChartExportCapabilities.evaluateFormat(
      request.format,
      hasDataSource:
          request.config != null ||
          request.jsonConfig != null ||
          request.rows != null,
      hasBoundaryKey: request.boundaryKey != null,
    );
  }

  /// Resolve whether each request has enough inputs to run.
  static ChartExportCapabilities capabilitiesForRequests(
    Iterable<ChartExportRequest> requests,
  ) {
    return ChartExportCapabilities(
      requests.map(ChartExporter.capabilityForRequest),
    );
  }

  /// Resolve which formats can be exported from the supplied sources.
  static ChartExportCapabilities capabilitiesForFormats({
    Iterable<ChartExportFormat> formats = ChartExportFormat.values,
    BaseChartConfig? config,
    Map<String, dynamic>? jsonConfig,
    List<List<Object?>>? rows,
    GlobalKey? boundaryKey,
  }) {
    return ChartExportCapabilities.evaluate(
      formats: formats,
      config: config,
      jsonConfig: jsonConfig,
      rows: rows,
      boundaryKey: boundaryKey,
    );
  }

  /// Return only formats that can be exported from the supplied sources.
  static List<ChartExportFormat> exportableFormats({
    Iterable<ChartExportFormat> formats = ChartExportFormat.values,
    BaseChartConfig? config,
    Map<String, dynamic>? jsonConfig,
    List<List<Object?>>? rows,
    GlobalKey? boundaryKey,
  }) {
    return capabilitiesForFormats(
      formats: formats,
      config: config,
      jsonConfig: jsonConfig,
      rows: rows,
      boundaryKey: boundaryKey,
    ).exportableFormats;
  }

  /// Build matching requests for several formats from a shared chart payload.
  static Future<ChartExportBatchResult> exportFormats({
    required Iterable<ChartExportFormat> formats,
    BaseChartConfig? config,
    Map<String, dynamic>? jsonConfig,
    List<List<Object?>>? rows,
    GlobalKey? boundaryKey,
    List<String>? categoryLabels,
    String? filename,
    String sheetName = 'Chart Data',
    String delimiter = ',',
    String lineEnding = '\r\n',
    double pixelRatio = 2.0,
    int jpegQuality = 90,
    Color jpegBackgroundColor = Colors.white,
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
    ChartExportBatchOptions batchOptions = const ChartExportBatchOptions(),
  }) {
    return exportAll(
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
          timeout: timeout,
          cancellationToken: cancellationToken,
        ),
      ),
      options: batchOptions,
    );
  }

  static ChartExportResult _exportCsv(
    ChartExportRequest request,
    String filename,
  ) {
    final rows = rowsForRequest(request);
    if (rows == null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: 'CSV export requires a chart config, JSON payload, or rows.',
      );
    }
    return ChartExportResult.text(
      format: request.format,
      filename: filename,
      text: rowsToCsv(
        rows,
        delimiter: request.delimiter,
        lineEnding: request.lineEnding,
      ),
    );
  }

  static ChartExportResult _exportXlsx(
    ChartExportRequest request,
    String filename,
  ) {
    final rows = rowsForRequest(request);
    if (rows == null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: 'XLSX export requires a chart config, JSON payload, or rows.',
      );
    }
    return ChartExportResult.bytes(
      format: request.format,
      filename: filename,
      bytes: rowsToXlsx(rows, sheetName: request.sheetName),
    );
  }

  static Future<ChartExportResult> _exportPng(
    ChartExportRequest request,
    String filename,
  ) async {
    final key = request.boundaryKey;
    if (key == null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: 'PNG export requires a repaint boundary key.',
      );
    }
    final bytes = await toPng(key, pixelRatio: request.pixelRatio);
    if (bytes == null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: 'PNG export failed to capture image bytes.',
      );
    }
    return ChartExportResult.bytes(
      format: request.format,
      filename: filename,
      bytes: bytes,
    );
  }

  static Future<ChartExportResult> _exportJpeg(
    ChartExportRequest request,
    String filename,
  ) async {
    final key = request.boundaryKey;
    if (key == null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: 'JPEG export requires a repaint boundary key.',
      );
    }
    final bytes = await toJpeg(
      key,
      pixelRatio: request.pixelRatio,
      quality: request.jpegQuality,
      backgroundColor: request.jpegBackgroundColor,
    );
    if (bytes == null) {
      return ChartExportResult.failure(
        format: request.format,
        filename: filename,
        error: 'JPEG export failed to capture image bytes.',
      );
    }
    return ChartExportResult.bytes(
      format: request.format,
      filename: filename,
      bytes: bytes,
    );
  }

  // ---- PNG / JPEG ----

  /// Capture the widget attached to [key] as PNG bytes.
  ///
  /// [pixelRatio] controls resolution (1.0 = screen pixels, 2.0 = 2× for retina).
  static Future<Uint8List?> toPng(
    GlobalKey key, {
    double pixelRatio = 2.0,
  }) async {
    if (!_isValidPixelRatio(pixelRatio)) return null;
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('ChartExporter.toPng error: $e');
      return null;
    }
  }

  /// Capture the widget attached to [key] as JPEG bytes.
  ///
  /// Flutter can encode PNG natively, but JPEG requires raw pixels plus a
  /// Dart encoder. Transparent pixels are flattened against [backgroundColor].
  static Future<Uint8List?> toJpeg(
    GlobalKey key, {
    double pixelRatio = 2.0,
    int quality = 90,
    Color backgroundColor = Colors.white,
  }) async {
    if (!_isValidPixelRatio(pixelRatio)) return null;
    try {
      final image = await toImage(key, pixelRatio: pixelRatio);
      if (image == null) return null;
      return imageToJpeg(
        image,
        quality: quality,
        backgroundColor: backgroundColor,
      );
    } catch (e) {
      debugPrint('ChartExporter.toJpeg error: $e');
      return null;
    }
  }

  /// Capture the widget attached to [key] in the requested image [format].
  static Future<Uint8List?> toImageBytes(
    GlobalKey key, {
    ChartImageExportFormat format = ChartImageExportFormat.png,
    double pixelRatio = 2.0,
    int jpegQuality = 90,
    Color jpegBackgroundColor = Colors.white,
  }) {
    return switch (format) {
      ChartImageExportFormat.png => toPng(key, pixelRatio: pixelRatio),
      ChartImageExportFormat.jpeg => toJpeg(
        key,
        pixelRatio: pixelRatio,
        quality: jpegQuality,
        backgroundColor: jpegBackgroundColor,
      ),
    };
  }

  /// Capture as a [ui.Image] (useful for in-app display / compositing).
  static Future<ui.Image?> toImage(
    GlobalKey key, {
    double pixelRatio = 2.0,
  }) async {
    if (!_isValidPixelRatio(pixelRatio)) return null;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    return boundary?.toImage(pixelRatio: pixelRatio);
  }

  /// Encode a captured [ui.Image] to JPEG bytes.
  static Future<Uint8List?> imageToJpeg(
    ui.Image image, {
    int quality = 90,
    Color backgroundColor = Colors.white,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final raw = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: byteData.buffer,
      bytesOffset: byteData.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final flattened = img.Image(width: raw.width, height: raw.height);
    img.fill(
      flattened,
      color: img.ColorRgb8(
        _colorChannel(backgroundColor.r),
        _colorChannel(backgroundColor.g),
        _colorChannel(backgroundColor.b),
      ),
    );
    img.compositeImage(flattened, raw);

    final normalizedQuality = quality.clamp(1, 100).toInt();
    return Uint8List.fromList(
      img.encodeJpg(flattened, quality: normalizedQuality),
    );
  }

  // ---- Tabular export: rows / CSV / XLSX ----

  /// Convert chart series into a rectangular table.
  static List<List<Object?>>? rowsForRequest(ChartExportRequest request) {
    final explicitRows = request.rows;
    if (explicitRows != null) return explicitRows;

    final payload = request.jsonConfig;
    if (payload != null) {
      final payloadRows = rowsFromPayload(
        payload,
        categoryLabels: request.categoryLabels,
      );
      if (payloadRows.isNotEmpty) return payloadRows;
    }

    final config = request.config;
    if (config != null) {
      return toRows(config, categoryLabels: request.categoryLabels);
    }

    return null;
  }

  /// Convert raw JSON chart payloads into rectangular export rows.
  ///
  /// This keeps data export useful for advanced charts whose canonical data
  /// lives outside `series`, such as `frames`, `nodes`/`links`, and nested
  /// hierarchy payloads.
  static List<List<Object?>> rowsFromPayload(
    Map<String, dynamic> payload, {
    List<String>? categoryLabels,
  }) {
    final frameRows = _barRaceRows(payload);
    if (frameRows.isNotEmpty) return frameRows;

    final flowRows = _flowRows(payload);
    if (flowRows.isNotEmpty) return flowRows;

    final hierarchyRows = _hierarchyRows(payload);
    if (hierarchyRows.isNotEmpty) return hierarchyRows;

    final seriesRows = _seriesPayloadRows(
      payload,
      categoryLabels: categoryLabels,
    );
    if (seriesRows.isNotEmpty) return seriesRows;

    final collectionRows = _firstCollectionRows(payload);
    if (collectionRows.isNotEmpty) return collectionRows;

    return const [];
  }

  static List<List<Object?>> _barRaceRows(Map<String, dynamic> payload) {
    final frames = _listValue(payload['frames']);
    if (frames.isEmpty) return const <List<Object?>>[];

    final categories = _stringPayloadList(payload['categories']);
    final frameLabels = _stringPayloadList(payload['frameLabels']);
    final rows = <List<Object?>>[
      <Object?>['Frame', 'Category', 'Value'],
    ];

    for (var frameIndex = 0; frameIndex < frames.length; frameIndex++) {
      final frame = frames[frameIndex];
      final fallbackLabel = frameIndex < frameLabels.length
          ? frameLabels[frameIndex]
          : frameIndex;
      if (frame is! Map) {
        final values = _listValue(frame);
        for (var valueIndex = 0; valueIndex < values.length; valueIndex++) {
          rows.add([
            fallbackLabel,
            valueIndex < categories.length
                ? categories[valueIndex]
                : valueIndex,
            _seriesCellValue(values[valueIndex]),
          ]);
        }
        continue;
      }

      final frameLabel =
          _firstPresent(frame, const [
            'label',
            'name',
            'title',
            'time',
            'year',
            'date',
          ]) ??
          fallbackLabel;
      final values = frame['values'] ?? frame['data'] ?? frame['items'];

      if (values is Map) {
        for (final item in values.entries) {
          rows.add([frameLabel, item.key, _seriesCellValue(item.value)]);
        }
        continue;
      }

      for (final item in _listValue(values)) {
        if (item is Map) {
          rows.add([
            frameLabel,
            _firstPresent(item, const ['category', 'name', 'label', 'id']),
            _firstPresent(item, const ['value', 'y', 'amount', 'count']),
          ]);
        } else {
          rows.add([frameLabel, rows.length - 1, _seriesCellValue(item)]);
        }
      }
    }

    return rows.length > 1 ? rows : const <List<Object?>>[];
  }

  static List<List<Object?>> _flowRows(Map<String, dynamic> payload) {
    final nodes = _firstListForKeys(payload, const ['nodes']);
    final links = _firstListForKeys(payload, const ['links', 'edges']);
    if (links.isEmpty) return const <List<Object?>>[];

    final rows = <List<Object?>>[
      <Object?>['Kind', 'Id', 'Name', 'Source', 'Target', 'Value'],
    ];

    for (final node in nodes) {
      if (node is Map) {
        rows.add([
          'node',
          _firstPresent(node, const ['id', 'key', 'name', 'label']),
          _firstPresent(node, const ['name', 'label', 'id', 'key']),
          '',
          '',
          _firstPresent(node, const ['value', 'weight', 'size', 'count']),
        ]);
      } else {
        rows.add(['node', node, node, '', '', '']);
      }
    }

    for (final link in links) {
      if (link is Map) {
        final source = _firstPresent(link, const ['source', 'from', 'start']);
        final target = _firstPresent(link, const ['target', 'to', 'end']);
        rows.add([
          'link',
          _firstPresent(link, const ['id', 'key']) ?? '',
          _firstPresent(link, const ['name', 'label']) ?? '',
          source,
          target,
          _firstPresent(link, const ['value', 'weight', 'amount', 'count']),
        ]);
        continue;
      }

      final values = _listValue(link);
      if (values.length >= 2) {
        rows.add([
          'link',
          '',
          '',
          values[0],
          values[1],
          values.length > 2 ? _seriesCellValue(values[2]) : null,
        ]);
      }
    }

    return rows.length > 1 ? rows : const <List<Object?>>[];
  }

  static List<List<Object?>> _hierarchyRows(Map<String, dynamic> payload) {
    final nodes = _firstListForKeys(payload, const ['nodes']);
    final hasNestedNodes = nodes.any(
      (node) => node is Map && _listValue(node['children']).isNotEmpty,
    );
    if (nodes.isNotEmpty &&
        nodes.every((node) => node is Map) &&
        !hasNestedNodes) {
      final rows = <List<Object?>>[
        <Object?>['Id', 'Parent', 'Label', 'Value'],
      ];

      for (final node in nodes.cast<Map>()) {
        rows.add([
          _firstPresent(node, const ['id', 'key', 'name', 'label']),
          _firstPresent(node, const ['parent', 'parentId', 'group']),
          _firstPresent(node, const ['label', 'name', 'id', 'key']),
          _firstPresent(node, const ['value', 'size', 'amount', 'count']),
        ]);
      }

      return rows;
    }

    final root = payload['root'] ?? payload['hierarchy'] ?? payload['tree'];
    if (root is Map) {
      return _nestedHierarchyRows(root);
    }

    final data = payload['data'];
    if (data is Map) {
      return _nestedHierarchyRows(data);
    }
    if (data is List &&
        data.any(
          (node) => node is Map && _listValue(node['children']).isNotEmpty,
        )) {
      return _nestedHierarchyListRows(data);
    }
    if (hasNestedNodes) {
      return _nestedHierarchyListRows(nodes);
    }

    return const <List<Object?>>[];
  }

  static List<List<Object?>> _nestedHierarchyRows(Map root) {
    return _nestedHierarchyListRows([root]);
  }

  static List<List<Object?>> _nestedHierarchyListRows(List roots) {
    final rows = <List<Object?>>[
      <Object?>['Path', 'Name', 'Parent', 'Depth', 'Value'],
    ];

    void visit(Map node, List<Object?> ancestors, String parent, int depth) {
      final label =
          _firstPresent(node, const ['label', 'name', 'id', 'key']) ??
          'Node ${rows.length}';
      final path = [...ancestors, label];
      rows.add([
        path.join(' / '),
        label,
        parent,
        depth,
        _firstPresent(node, const ['value', 'size', 'amount', 'count']),
      ]);

      for (final child in _listValue(node['children'])) {
        if (child is Map) {
          visit(child, path, label.toString(), depth + 1);
        }
      }
    }

    for (final root in roots) {
      if (root is Map) {
        visit(root, const [], '', 0);
      }
    }
    return rows.length > 1 ? rows : const <List<Object?>>[];
  }

  static List<List<Object?>> _seriesPayloadRows(
    Map<String, dynamic> payload, {
    List<String>? categoryLabels,
  }) {
    final series = _listValue(payload['series']).whereType<Map>().toList();
    if (series.isEmpty) return const <List<Object?>>[];

    final seriesData = [for (final item in series) _seriesDataValues(item)];
    final maxLength = seriesData.fold<int>(
      0,
      (length, values) => values.length > length ? values.length : length,
    );
    if (maxLength == 0) return const <List<Object?>>[];

    final rows = <List<Object?>>[
      <Object?>[
        'Category',
        for (var index = 0; index < series.length; index++)
          _firstPresent(series[index], const ['name', 'label', 'id']) ??
              'Series ${index + 1}',
      ],
    ];

    for (var rowIndex = 0; rowIndex < maxLength; rowIndex++) {
      rows.add([
        categoryLabels != null && rowIndex < categoryLabels.length
            ? categoryLabels[rowIndex]
            : rowIndex,
        for (final values in seriesData)
          rowIndex < values.length ? _seriesCellValue(values[rowIndex]) : null,
      ]);
    }

    return rows;
  }

  static List<List<Object?>> _firstCollectionRows(
    Map<String, dynamic> payload,
  ) {
    for (final entry in payload.entries) {
      if (const {
        'frames',
        'series',
        'links',
        'edges',
        'nodes',
      }.contains(entry.key)) {
        continue;
      }

      final rows = _collectionRows(entry.value);
      if (rows.isNotEmpty) {
        return rows;
      }
    }

    return const <List<Object?>>[];
  }

  static List<List<Object?>> _collectionRows(Object? value) {
    final values = _listValue(value);
    if (values.isEmpty) return const <List<Object?>>[];

    final maps = values.whereType<Map>().toList();
    if (maps.length == values.length) {
      final keys = <Object?>[];
      for (final item in maps) {
        for (final key in item.keys) {
          if (!keys.contains(key)) {
            keys.add(key);
          }
        }
      }

      if (keys.isEmpty) return const <List<Object?>>[];
      return [
        keys,
        for (final item in maps)
          [for (final key in keys) _seriesCellValue(item[key])],
      ];
    }

    return [
      <Object?>['Index', 'Value'],
      for (var index = 0; index < values.length; index++)
        [index, _seriesCellValue(values[index])],
    ];
  }

  static List<Object?> _seriesDataValues(Map series) {
    final data = series['data'] ?? series['values'] ?? series['items'];
    if (data is Map) {
      return data.values.toList(growable: false);
    }

    return _listValue(data);
  }

  static List<Object?> _firstListForKeys(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final values = _listValue(payload[key]);
      if (values.isNotEmpty) {
        return values;
      }
    }

    for (final series in _listValue(payload['series'])) {
      if (series is! Map) {
        continue;
      }

      for (final key in keys) {
        final values = _listValue(series[key]);
        if (values.isNotEmpty) {
          return values;
        }
      }
    }

    return const <Object?>[];
  }

  static List<Object?> _listValue(Object? value) {
    if (value is Iterable) {
      return value.toList(growable: false);
    }

    return const <Object?>[];
  }

  static Object? _firstPresent(Map value, List<String> keys) {
    for (final key in keys) {
      if (value.containsKey(key)) {
        return _seriesCellValue(value[key]);
      }
    }

    return null;
  }

  static List<String> _stringPayloadList(Object? value) {
    if (value is! Iterable) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  /// Convert chart series into a rectangular table.
  static List<List<Object?>> toRows(
    BaseChartConfig config, {
    List<String>? categoryLabels,
  }) {
    final series = config.series;
    if (series.isEmpty) return const [];

    final rows = <List<Object?>>[
      <Object?>['Category', for (final s in series) s.name ?? 'Series'],
    ];

    var maxLen = 0;
    for (final s in series) {
      final length = s.data?.length ?? 0;
      if (length > maxLen) maxLen = length;
    }

    for (var i = 0; i < maxLen; i++) {
      rows.add([
        categoryLabels != null && i < categoryLabels.length
            ? categoryLabels[i]
            : i,
        for (final s in series)
          _seriesCellValue(
            s.data != null && i < s.data!.length ? s.data![i] : null,
          ),
      ]);
    }

    return rows;
  }

  /// Serialise series data in [config] to a CSV string.
  ///
  /// Format:
  /// ```
  /// Category,Series A,Series B
  /// Jan,120,95
  /// Feb,145,110
  /// ```
  static String toCsv(
    BaseChartConfig config, {
    List<String>? categoryLabels,
    String delimiter = ',',
    String lineEnding = '\r\n',
  }) {
    return rowsToCsv(
      toRows(config, categoryLabels: categoryLabels),
      delimiter: delimiter,
      lineEnding: lineEnding,
    );
  }

  /// Serialise already-normalized tabular rows to CSV.
  static String rowsToCsv(
    List<List<Object?>> rows, {
    String delimiter = ',',
    String lineEnding = '\r\n',
  }) {
    return rows
        .map(
          (row) => row
              .map((cell) => _csvEscape(_tabularCellText(cell), delimiter))
              .join(delimiter),
        )
        .join(lineEnding);
  }

  /// Serialise series data in [config] to a minimal valid XLSX workbook.
  ///
  /// The generated workbook uses uncompressed ZIP entries and inline strings so
  /// it stays dependency-free and works consistently across Flutter platforms.
  static Uint8List toXlsx(
    BaseChartConfig config, {
    List<String>? categoryLabels,
    String sheetName = 'Chart Data',
  }) {
    return rowsToXlsx(
      toRows(config, categoryLabels: categoryLabels),
      sheetName: sheetName,
    );
  }

  /// Encode already-normalized tabular rows as an XLSX workbook.
  static Uint8List rowsToXlsx(
    List<List<Object?>> rows, {
    String sheetName = 'Chart Data',
  }) {
    final normalizedSheetName = _sanitizeSheetName(sheetName);
    final worksheetXml = _buildWorksheetXml(rows);
    final workbookXml = _buildWorkbookXml(normalizedSheetName);
    return ChartZipStoreWriter.writeText({
      '[Content_Types].xml': _contentTypesXml,
      '_rels/.rels': _rootRelsXml,
      'xl/workbook.xml': workbookXml,
      'xl/_rels/workbook.xml.rels': _workbookRelsXml,
      'xl/worksheets/sheet1.xml': worksheetXml,
    });
  }

  static String _csvEscape(String s, String delimiter) {
    if (s.contains(delimiter) ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Object? _seriesCellValue(Object? value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    if (value is Map) {
      for (final key in const ['value', 'y', 'amount', 'count']) {
        if (value.containsKey(key)) return _seriesCellValue(value[key]);
      }
      return jsonEncode(value);
    }
    if (value is Iterable) {
      final values = value.toList(growable: false);
      if (values.isEmpty) return '';
      if (values.length == 1) return _seriesCellValue(values.first);
      return jsonEncode(values);
    }
    return value.toString();
  }

  static String _tabularCellText(Object? cell) {
    if (cell == null) return '';
    if (cell is num) {
      if (cell.isNaN || !cell.isFinite) return '';
    }
    return cell.toString();
  }

  static bool _isNumericCell(Object? value) {
    return value is num && value.isFinite && !value.isNaN;
  }

  static String _buildWorksheetXml(List<List<Object?>> rows) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      ..write('<sheetData>');

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final rowNumber = rowIndex + 1;
      buffer.write('<row r="$rowNumber">');
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final cell = row[columnIndex];
        final reference = '${_columnName(columnIndex + 1)}$rowNumber';
        if (_isNumericCell(cell)) {
          buffer.write('<c r="$reference"><v>$cell</v></c>');
        } else {
          buffer.write(
            '<c r="$reference" t="inlineStr"><is><t>${_xmlEscape(_tabularCellText(cell))}</t></is></c>',
          );
        }
      }
      buffer.write('</row>');
    }

    buffer
      ..write('</sheetData>')
      ..write('</worksheet>');
    return buffer.toString();
  }

  static String _buildWorkbookXml(String sheetName) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="${_xmlEscape(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
        '</workbook>';
  }

  static String _columnName(int index) {
    final chars = <String>[];
    var value = index;
    while (value > 0) {
      value--;
      chars.insert(0, String.fromCharCode(65 + value % 26));
      value ~/= 26;
    }
    return chars.join();
  }

  static String _sanitizeSheetName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\[\]\:\*\?\/\\]'), ' ').trim();
    final fallback = sanitized.isEmpty ? 'Chart Data' : sanitized;
    return fallback.length > 31 ? fallback.substring(0, 31) : fallback;
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static int _colorChannel(double channel) {
    return (channel * 255.0).round().clamp(0, 255).toInt();
  }

  static const String _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';

  static const String _rootRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _workbookRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>';
}

// ---------------------------------------------------------------------------
// ExportableChart widget
// ---------------------------------------------------------------------------

/// Wraps a chart widget in a [RepaintBoundary] with a managed [GlobalKey].
///
/// Call [ExportableChartController.capture()] to get PNG bytes.
///
/// ```dart
/// final ctrl = ExportableChartController();
///
/// ExportableChart(
///   controller: ctrl,
///   child: TenunChart(config: myConfig),
/// )
///
/// // Later:
/// final bytes = await ctrl.capture();
/// ```
class ExportableChartController {
  final GlobalKey _key = GlobalKey();

  /// Repaint boundary key managed by [ExportableChart].
  ///
  /// Exposed so UI helpers such as [ChartExportControls] can trigger image
  /// exports without duplicating key ownership.
  GlobalKey get boundaryKey => _key;

  Future<Uint8List?> capture({double pixelRatio = 2.0}) =>
      ChartExporter.toPng(_key, pixelRatio: pixelRatio);

  Future<Uint8List?> captureJpeg({
    double pixelRatio = 2.0,
    int quality = 90,
    Color backgroundColor = Colors.white,
  }) => ChartExporter.toJpeg(
    _key,
    pixelRatio: pixelRatio,
    quality: quality,
    backgroundColor: backgroundColor,
  );

  Future<Uint8List?> captureBytes({
    ChartImageExportFormat format = ChartImageExportFormat.png,
    double pixelRatio = 2.0,
    int jpegQuality = 90,
    Color jpegBackgroundColor = Colors.white,
  }) => ChartExporter.toImageBytes(
    _key,
    format: format,
    pixelRatio: pixelRatio,
    jpegQuality: jpegQuality,
    jpegBackgroundColor: jpegBackgroundColor,
  );

  Future<ui.Image?> captureImage({double pixelRatio = 2.0}) =>
      ChartExporter.toImage(_key, pixelRatio: pixelRatio);
}

class ExportableChart extends StatelessWidget {
  final ExportableChartController controller;
  final Widget child;

  const ExportableChart({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: controller._key, child: child);
  }
}

// ---------------------------------------------------------------------------
// SvgChartExporter — lightweight SVG generation (no external dependency)
// ---------------------------------------------------------------------------

/// Generates a minimal SVG string for simple chart types.
///
/// Intended for:
/// - Server-side chart thumbnails
/// - PDF embedding (via flutter_svg or webview)
/// - Email reports
///
/// Only covers bar, line, and pie. Complex charts (sankey, treemap) require
/// a full render-to-canvas → PNG pipeline instead.
class SvgChartExporter {
  /// Generate a bar chart SVG.
  static String barChart({
    required List<double> values,
    required List<String> labels,
    double width = 400,
    double height = 250,
    List<String>? colors,
    String title = '',
  }) {
    if (values.isEmpty) return _emptySvg(width, height);
    final buf = StringBuffer();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    const padLeft = 40.0, padBottom = 30.0, padTop = 30.0, padRight = 10.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;
    final barW = chartW / values.length;

    buf.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">',
    );
    if (title.isNotEmpty) {
      buf.writeln(
        '<text x="${width / 2}" y="16" text-anchor="middle" font-size="14" font-weight="bold" fill="#1a1a1a">$title</text>',
      );
    }

    // Grid lines (5 horizontal).
    for (int i = 0; i <= 5; i++) {
      final y = padTop + chartH - (i / 5) * chartH;
      final label = (maxV * i / 5).toStringAsFixed(0);
      buf.writeln(
        '<line x1="$padLeft" y1="$y" x2="${width - padRight}" y2="$y" '
        'stroke="#e0e0e0" stroke-width="0.5"/>',
      );
      buf.writeln(
        '<text x="${padLeft - 4}" y="${y + 4}" text-anchor="end" '
        'font-size="9" fill="#666">$label</text>',
      );
    }

    // Bars.
    for (int i = 0; i < values.length; i++) {
      final barH = maxV > 0 ? (values[i] / maxV) * chartH : 0;
      final x = padLeft + i * barW + barW * 0.1;
      final y = padTop + chartH - barH;
      final color = colors != null && i < colors.length
          ? colors[i]
          : _defaultColors[i % _defaultColors.length];
      buf.writeln(
        '<rect x="${x.toStringAsFixed(1)}" y="${y.toStringAsFixed(1)}" '
        'width="${(barW * 0.8).toStringAsFixed(1)}" '
        'height="${barH.toStringAsFixed(1)}" fill="$color" rx="2"/>',
      );
      if (i < labels.length) {
        final lx = padLeft + i * barW + barW / 2;
        buf.writeln(
          '<text x="${lx.toStringAsFixed(1)}" y="${(height - padBottom + 12).toStringAsFixed(1)}" '
          'text-anchor="middle" font-size="9" fill="#444">${labels[i]}</text>',
        );
      }
    }

    buf.writeln('</svg>');
    return buf.toString();
  }

  /// Generate a line chart SVG.
  static String lineChart({
    required List<double> values,
    double width = 400,
    double height = 250,
    String color = '#2196F3',
    bool filled = false,
    String title = '',
  }) {
    if (values.isEmpty) return _emptySvg(width, height);
    const padLeft = 40.0, padBottom = 20.0, padTop = 30.0, padRight = 10.0;
    final chartW = width - padLeft - padRight;
    final chartH = height - padTop - padBottom;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs().clamp(1.0, double.infinity);

    Offset toCanvas(int i) {
      final x = padLeft + (i / (values.length - 1)) * chartW;
      final y = padTop + chartH - ((values[i] - minV) / range) * chartH;
      return Offset(x, y);
    }

    final pts = List.generate(values.length, (i) => toCanvas(i));
    final d = pts
        .asMap()
        .entries
        .map(
          (e) =>
              '${e.key == 0 ? 'M' : 'L'}${e.value.dx.toStringAsFixed(1)},${e.value.dy.toStringAsFixed(1)}',
        )
        .join(' ');

    final buf = StringBuffer();
    buf.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">',
    );
    if (title.isNotEmpty) {
      buf.writeln(
        '<text x="${width / 2}" y="16" text-anchor="middle" font-size="14" '
        'font-weight="bold" fill="#1a1a1a">$title</text>',
      );
    }
    if (filled) {
      final first = pts.first;
      final last = pts.last;
      final fillD =
          '$d L${last.dx.toStringAsFixed(1)},${(padTop + chartH).toStringAsFixed(1)} '
          'L${first.dx.toStringAsFixed(1)},${(padTop + chartH).toStringAsFixed(1)} Z';
      buf.writeln(
        '<path d="$fillD" fill="$color" fill-opacity="0.15" stroke="none"/>',
      );
    }
    buf.writeln(
      '<path d="$d" stroke="$color" stroke-width="2" fill="none" stroke-linejoin="round"/>',
    );
    buf.writeln('</svg>');
    return buf.toString();
  }

  static String _emptySvg(double w, double h) =>
      '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h">'
      '<text x="${w / 2}" y="${h / 2}" text-anchor="middle" fill="#999">No data</text>'
      '</svg>';

  static const _defaultColors = [
    '#2196F3',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#607D8B',
  ];
}
