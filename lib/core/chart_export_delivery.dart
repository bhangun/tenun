import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'chart_export.dart';
import 'chart_export_filename.dart';

typedef ChartExportFileHandler = FutureOr<void> Function(ChartExportFile file);
typedef ChartExportDeliveryBatchProgressHandler =
    void Function(ChartExportDeliveryBatchProgress progress);
typedef ChartExportDeliveryBatchProgressErrorHandler =
    void Function(
      Object error,
      StackTrace stackTrace,
      ChartExportDeliveryBatchProgress progress,
    );
typedef ChartExportDeliveryRetryPredicate =
    bool Function(
      ChartExportDeliveryResult result,
      int attempt,
      int maxAttempts,
    );
typedef ChartExportDeliveryRetryDelayBuilder =
    Duration Function(
      ChartExportDeliveryResult result,
      int attempt,
      int maxAttempts,
    );

enum ChartExportDeliveryIntent { save, share, download, custom }

class ChartExportFile {
  ChartExportFile({
    required String filename,
    required this.mimeType,
    required this.bytes,
    this.text,
    this.format,
    Map<String, Object?> metadata = const {},
  }) : filename = ChartExportFilename.sanitize(filename),
       metadata = Map.unmodifiable(metadata);

  factory ChartExportFile.fromResult(ChartExportResult result) {
    final file = ChartExportFile.tryFromResult(result);
    if (file != null) return file;

    final error = result.error ?? 'Export result has no payload.';
    throw StateError(
      'Cannot create export file for ${result.filename}: $error',
    );
  }

  static ChartExportFile? tryFromResult(ChartExportResult result) {
    if (!result.success) return null;

    final payload = result.payloadBytes;
    if (payload == null) return null;

    return ChartExportFile(
      filename: result.filename,
      mimeType: result.mimeType,
      bytes: payload,
      text: result.text,
      format: result.format,
      metadata: result.toMetadataJson(),
    );
  }

  final String filename;
  final String mimeType;
  final Uint8List bytes;
  final String? text;
  final ChartExportFormat? format;
  final Map<String, Object?> metadata;

  bool get isText => text != null;

  bool get isBinary => text == null;

  int get sizeBytes => bytes.length;

  String get extension {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == filename.length - 1) return '';
    return filename.substring(dotIndex + 1).toLowerCase();
  }

  String get base64Payload => base64Encode(bytes);

  String get dataUri => 'data:$mimeType;base64,$base64Payload';

  String contentDisposition({bool attachment = true}) {
    final disposition = attachment ? 'attachment' : 'inline';
    return '$disposition; filename="${_escapeHttpHeaderValue(filename)}"';
  }

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    return {
      'filename': filename,
      'mimeType': mimeType,
      'format': format?.name,
      'extension': extension,
      'sizeBytes': sizeBytes,
      'isText': isText,
      'isBinary': isBinary,
      'metadata': metadata,
      if (includePayload && text != null) 'text': text,
      if (includePayload) 'base64': base64Payload,
    };
  }

  static String _escapeHttpHeaderValue(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}

class ChartExportDeliveryResult {
  const ChartExportDeliveryResult._({
    required this.success,
    required this.attempts,
    required this.retryErrors,
    required this.metadata,
    this.file,
    this.error,
    this.stackTrace,
    this.duration,
  });

  factory ChartExportDeliveryResult.success(
    ChartExportFile file, {
    int attempts = 1,
    Iterable<String> retryErrors = const [],
    Map<String, Object?> metadata = const {},
    Duration? duration,
  }) {
    return ChartExportDeliveryResult._(
      success: true,
      file: file,
      attempts: attempts,
      retryErrors: List.unmodifiable(retryErrors),
      metadata: Map.unmodifiable(metadata),
      duration: duration,
    );
  }

  factory ChartExportDeliveryResult.failure({
    ChartExportFile? file,
    required Object error,
    StackTrace? stackTrace,
    int attempts = 1,
    Iterable<String> retryErrors = const [],
    Map<String, Object?> metadata = const {},
    Duration? duration,
  }) {
    return ChartExportDeliveryResult._(
      success: false,
      file: file,
      error: error,
      stackTrace: stackTrace,
      attempts: attempts,
      retryErrors: List.unmodifiable(retryErrors),
      metadata: Map.unmodifiable(metadata),
      duration: duration,
    );
  }

  final bool success;
  final int attempts;
  final List<String> retryErrors;
  final ChartExportFile? file;
  final Object? error;
  final StackTrace? stackTrace;
  final Duration? duration;
  final Map<String, Object?> metadata;

  String? get filename => file?.filename ?? _metadataString('filename');

  int get sizeBytes => success ? file?.sizeBytes ?? 0 : 0;

  String? get errorText => error?.toString();

  String? _metadataString(String key) {
    final value = metadata[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    final elapsed = duration;
    return {
      'success': success,
      'attempts': attempts,
      if (elapsed != null) 'durationMicros': elapsed.inMicroseconds,
      if (elapsed != null) 'durationMs': elapsed.inMicroseconds / 1000,
      if (retryErrors.isNotEmpty) 'retryErrors': retryErrors,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (file != null)
        'file': file!.toMetadataJson(includePayload: includePayload),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }

  ChartExportDeliveryResult withDuration(Duration duration) {
    return ChartExportDeliveryResult._(
      success: success,
      attempts: attempts,
      retryErrors: retryErrors,
      metadata: metadata,
      file: file,
      error: error,
      stackTrace: stackTrace,
      duration: duration,
    );
  }
}

class ChartExportDeliveryBatchResult {
  ChartExportDeliveryBatchResult(Iterable<ChartExportDeliveryResult> results)
    : results = List.unmodifiable(results);

  final List<ChartExportDeliveryResult> results;

  bool get success => results.every((result) => result.success);

  bool get hasFailures => results.any((result) => !result.success);

  bool get hasOutput => outputCount > 0;

  bool get hasIssues => issueCount > 0;

  int get successCount => results.where((result) => result.success).length;

  int get outputCount => successCount;

  int get failureCount => results.length - successCount;

  int get issueCount => failureCount;

  int get totalSizeBytes =>
      results.fold<int>(0, (total, result) => total + result.sizeBytes);

  int get totalDurationMicros => results.fold<int>(
    0,
    (total, result) => total + (result.duration?.inMicroseconds ?? 0),
  );

  List<ChartExportDeliveryResult> get successful =>
      List.unmodifiable(results.where((result) => result.success));

  List<ChartExportDeliveryResult> get failed =>
      List.unmodifiable(results.where((result) => !result.success));

  List<ChartExportFile> get files => List.unmodifiable(
    successful.map((result) => result.file!).whereType<ChartExportFile>(),
  );

  List<String> get issueMessages {
    final messages = <String>[];
    void addIssue(String message) {
      final normalized = message.trim();
      if (normalized.isEmpty || messages.contains(normalized)) return;
      messages.add(normalized);
    }

    for (final result in failed) {
      addIssue(
        'Delivery failed for ${result.filename ?? 'export file'}: '
        '${result.errorText ?? 'Unknown delivery error.'}',
      );
    }

    return List.unmodifiable(messages);
  }

  String? get primaryIssue =>
      issueMessages.isEmpty ? null : issueMessages.first;

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    return {
      'success': success,
      'count': results.length,
      'successCount': successCount,
      'outputCount': outputCount,
      'failureCount': failureCount,
      'issueCount': issueCount,
      'hasOutput': hasOutput,
      'hasIssues': hasIssues,
      if (primaryIssue != null) 'primaryIssue': primaryIssue,
      if (issueMessages.isNotEmpty) 'issues': issueMessages,
      'totalSizeBytes': totalSizeBytes,
      if (totalDurationMicros > 0) 'totalDurationMicros': totalDurationMicros,
      if (totalDurationMicros > 0)
        'totalDurationMs': totalDurationMicros / 1000,
      'results': [
        for (final result in results)
          result.toMetadataJson(includePayload: includePayload),
      ],
    };
  }
}

class ChartExportDeliveryBatchProgress {
  const ChartExportDeliveryBatchProgress({
    required this.completed,
    required this.total,
    required this.result,
  });

  final int completed;
  final int total;
  final ChartExportDeliveryResult result;

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

class ChartExportDeliveryBatchOptions {
  const ChartExportDeliveryBatchOptions({
    this.stopOnFirstFailure = false,
    this.continueOnProgressError = false,
    this.timeout,
    this.cancellationToken,
    this.onProgress,
    this.onProgressError,
  });

  final bool stopOnFirstFailure;
  final bool continueOnProgressError;
  final Duration? timeout;
  final ChartExportCancellationToken? cancellationToken;
  final ChartExportDeliveryBatchProgressHandler? onProgress;
  final ChartExportDeliveryBatchProgressErrorHandler? onProgressError;
}

abstract class ChartExportDeliveryAdapter {
  ChartExportDeliveryIntent get intent;

  Future<ChartExportDeliveryResult> deliver(ChartExportFile file);

  Future<ChartExportDeliveryBatchResult> deliverAll(
    Iterable<ChartExportFile> files,
  ) {
    return ChartExportDelivery.deliverFiles(files, this);
  }
}

class ChartExportCallbackDeliveryAdapter implements ChartExportDeliveryAdapter {
  const ChartExportCallbackDeliveryAdapter({
    required this.onFile,
    this.intent = ChartExportDeliveryIntent.custom,
  });

  const ChartExportCallbackDeliveryAdapter.save({required this.onFile})
    : intent = ChartExportDeliveryIntent.save;

  const ChartExportCallbackDeliveryAdapter.share({required this.onFile})
    : intent = ChartExportDeliveryIntent.share;

  const ChartExportCallbackDeliveryAdapter.download({required this.onFile})
    : intent = ChartExportDeliveryIntent.download;

  final ChartExportFileHandler onFile;

  @override
  final ChartExportDeliveryIntent intent;

  @override
  Future<ChartExportDeliveryResult> deliver(ChartExportFile file) async {
    try {
      await onFile(file);
      return ChartExportDeliveryResult.success(file);
    } catch (error, stackTrace) {
      return ChartExportDeliveryResult.failure(
        file: file,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<ChartExportDeliveryBatchResult> deliverAll(
    Iterable<ChartExportFile> files,
  ) {
    return ChartExportDelivery.deliverFiles(files, this);
  }
}

class ChartExportMemoryDeliveryAdapter implements ChartExportDeliveryAdapter {
  ChartExportMemoryDeliveryAdapter({
    this.intent = ChartExportDeliveryIntent.custom,
  });

  final List<ChartExportFile> _files = [];

  @override
  final ChartExportDeliveryIntent intent;

  List<ChartExportFile> get files => List.unmodifiable(_files);

  void clear() => _files.clear();

  @override
  Future<ChartExportDeliveryResult> deliver(ChartExportFile file) async {
    _files.add(file);
    return ChartExportDeliveryResult.success(file);
  }

  @override
  Future<ChartExportDeliveryBatchResult> deliverAll(
    Iterable<ChartExportFile> files,
  ) {
    return ChartExportDelivery.deliverFiles(files, this);
  }
}

class ChartExportDryRunDeliveryAdapter implements ChartExportDeliveryAdapter {
  const ChartExportDryRunDeliveryAdapter({
    this.intent = ChartExportDeliveryIntent.custom,
  });

  @override
  final ChartExportDeliveryIntent intent;

  @override
  Future<ChartExportDeliveryResult> deliver(ChartExportFile file) async {
    return ChartExportDeliveryResult.success(
      file,
      metadata: {
        'adapter': 'dryRun',
        'intent': intent.name,
        'sideEffects': false,
      },
    );
  }

  @override
  Future<ChartExportDeliveryBatchResult> deliverAll(
    Iterable<ChartExportFile> files,
  ) {
    return ChartExportDelivery.deliverFiles(files, this);
  }
}

class ChartExportCompositeDeliveryAdapter
    implements ChartExportDeliveryAdapter {
  ChartExportCompositeDeliveryAdapter(
    Iterable<ChartExportDeliveryAdapter> adapters, {
    this.intent = ChartExportDeliveryIntent.custom,
    this.stopOnFirstFailure = true,
  }) : adapters = List.unmodifiable(adapters);

  final List<ChartExportDeliveryAdapter> adapters;
  final bool stopOnFirstFailure;

  @override
  final ChartExportDeliveryIntent intent;

  @override
  Future<ChartExportDeliveryResult> deliver(ChartExportFile file) async {
    if (adapters.isEmpty) {
      return ChartExportDeliveryResult.failure(
        file: file,
        error: 'No delivery adapters were configured.',
        metadata: _metadata(const []),
      );
    }

    final results = <ChartExportDeliveryResult>[];
    for (var index = 0; index < adapters.length; index++) {
      final result = await _deliverWithAdapter(adapters[index], file);
      results.add(result);
      if (!result.success && stopOnFirstFailure) {
        return ChartExportDeliveryResult.failure(
          file: result.file ?? file,
          error:
              'Composite delivery failed at adapter ${index + 1}/'
              '${adapters.length}: ${result.errorText ?? 'Delivery failed.'}',
          stackTrace: result.stackTrace,
          metadata: _metadata(results),
        );
      }
    }

    final failedCount = results.where((result) => !result.success).length;
    if (failedCount > 0) {
      return ChartExportDeliveryResult.failure(
        file: file,
        error:
            'Composite delivery failed for $failedCount of '
            '${adapters.length} adapters.',
        metadata: _metadata(results),
      );
    }

    return ChartExportDeliveryResult.success(
      file,
      metadata: _metadata(results),
    );
  }

  @override
  Future<ChartExportDeliveryBatchResult> deliverAll(
    Iterable<ChartExportFile> files,
  ) {
    return ChartExportDelivery.deliverFiles(files, this);
  }

  Future<ChartExportDeliveryResult> _deliverWithAdapter(
    ChartExportDeliveryAdapter adapter,
    ChartExportFile file,
  ) async {
    try {
      return await adapter.deliver(file);
    } catch (error, stackTrace) {
      return ChartExportDeliveryResult.failure(
        file: file,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, Object?> _metadata(List<ChartExportDeliveryResult> results) {
    final successCount = results.where((result) => result.success).length;
    return {
      'adapter': 'composite',
      'intent': intent.name,
      'adapterCount': adapters.length,
      'attemptedAdapterCount': results.length,
      'successCount': successCount,
      'failureCount': results.length - successCount,
      'stopOnFirstFailure': stopOnFirstFailure,
      'delegates': List.unmodifiable([
        for (var index = 0; index < results.length; index++)
          Map<String, Object?>.unmodifiable({
            'index': index,
            'intent': adapters[index].intent.name,
            'result': results[index].toMetadataJson(),
          }),
      ]),
    };
  }
}

class ChartExportRetryDeliveryAdapter implements ChartExportDeliveryAdapter {
  const ChartExportRetryDeliveryAdapter({
    required this.delegate,
    this.maxAttempts = 3,
    this.delay = Duration.zero,
    this.shouldRetry,
    this.delayBuilder,
  });

  final ChartExportDeliveryAdapter delegate;
  final int maxAttempts;
  final Duration delay;
  final ChartExportDeliveryRetryPredicate? shouldRetry;
  final ChartExportDeliveryRetryDelayBuilder? delayBuilder;

  @override
  ChartExportDeliveryIntent get intent => delegate.intent;

  @override
  Future<ChartExportDeliveryResult> deliver(ChartExportFile file) async {
    final limit = maxAttempts < 1 ? 1 : maxAttempts;
    final errors = <String>[];

    for (var attempt = 1; attempt <= limit; attempt++) {
      final result = await _attemptDeliver(file, attempt, errors);
      if (result.success) {
        return ChartExportDeliveryResult.success(
          result.file ?? file,
          attempts: attempt,
          retryErrors: errors,
        );
      }

      errors.add(result.errorText ?? 'Delivery failed.');
      final canRetry = attempt < limit && _shouldRetry(result, attempt, limit);
      if (!canRetry) {
        return ChartExportDeliveryResult.failure(
          file: result.file ?? file,
          error: result.error ?? 'Delivery failed.',
          stackTrace: result.stackTrace,
          attempts: attempt,
          retryErrors: errors,
        );
      }

      await _waitBeforeRetry(result, attempt, limit);
    }

    return ChartExportDeliveryResult.failure(
      file: file,
      error: 'Delivery failed.',
      attempts: limit,
      retryErrors: errors,
    );
  }

  @override
  Future<ChartExportDeliveryBatchResult> deliverAll(
    Iterable<ChartExportFile> files,
  ) {
    return ChartExportDelivery.deliverFiles(files, this);
  }

  Future<ChartExportDeliveryResult> _attemptDeliver(
    ChartExportFile file,
    int attempt,
    List<String> retryErrors,
  ) async {
    try {
      return await delegate.deliver(file);
    } catch (error, stackTrace) {
      return ChartExportDeliveryResult.failure(
        file: file,
        error: error,
        stackTrace: stackTrace,
        attempts: attempt,
        retryErrors: retryErrors,
      );
    }
  }

  bool _shouldRetry(ChartExportDeliveryResult result, int attempt, int limit) {
    return shouldRetry?.call(result, attempt, limit) ?? true;
  }

  Future<void> _waitBeforeRetry(
    ChartExportDeliveryResult result,
    int attempt,
    int limit,
  ) async {
    final wait = delayBuilder?.call(result, attempt, limit) ?? delay;
    if (wait.inMicroseconds <= 0) return;
    await Future<void>.delayed(wait);
  }
}

class ChartExportDelivery {
  const ChartExportDelivery._();

  static ChartExportDeliveryAdapter withRetry(
    ChartExportDeliveryAdapter adapter, {
    int maxAttempts = 3,
    Duration delay = Duration.zero,
    ChartExportDeliveryRetryPredicate? shouldRetry,
    ChartExportDeliveryRetryDelayBuilder? delayBuilder,
  }) {
    return ChartExportRetryDeliveryAdapter(
      delegate: adapter,
      maxAttempts: maxAttempts,
      delay: delay,
      shouldRetry: shouldRetry,
      delayBuilder: delayBuilder,
    );
  }

  static ChartExportDeliveryAdapter dryRun({
    ChartExportDeliveryIntent intent = ChartExportDeliveryIntent.custom,
  }) {
    return ChartExportDryRunDeliveryAdapter(intent: intent);
  }

  static ChartExportDeliveryAdapter chain(
    Iterable<ChartExportDeliveryAdapter> adapters, {
    ChartExportDeliveryIntent intent = ChartExportDeliveryIntent.custom,
    bool stopOnFirstFailure = true,
  }) {
    return ChartExportCompositeDeliveryAdapter(
      adapters,
      intent: intent,
      stopOnFirstFailure: stopOnFirstFailure,
    );
  }

  static ChartExportFile fileFromResult(ChartExportResult result) {
    return ChartExportFile.fromResult(result);
  }

  static List<ChartExportFile> filesFromResults(
    Iterable<ChartExportResult> results,
  ) {
    return List.unmodifiable(
      results.map(ChartExportFile.tryFromResult).whereType<ChartExportFile>(),
    );
  }

  static List<ChartExportFile> filesFromBatch(ChartExportBatchResult batch) {
    return filesFromResults(batch.results);
  }

  static Future<ChartExportDeliveryResult> deliverResult(
    ChartExportResult result,
    ChartExportDeliveryAdapter adapter, {
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
  }) async {
    final file = ChartExportFile.tryFromResult(result);
    if (file == null) {
      return ChartExportDeliveryResult.failure(
        error: result.error ?? 'Export result has no payload.',
        metadata: {
          'source': 'exportResult',
          'filename': result.filename,
          'format': result.format.name,
        },
      );
    }
    return deliverFile(
      file,
      adapter,
      timeout: timeout,
      cancellationToken: cancellationToken,
    );
  }

  static Future<ChartExportDeliveryResult> deliverFile(
    ChartExportFile file,
    ChartExportDeliveryAdapter adapter, {
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (cancellationToken?.isCancelled == true) {
      return _cancelledDeliveryResult(
        file,
        cancellationToken,
      ).withDuration(stopwatch.elapsed);
    }
    try {
      final result = await _guardDelivery(
        () => adapter.deliver(file),
        file,
        timeout: timeout,
        cancellationToken: cancellationToken,
      );
      return result.withDuration(stopwatch.elapsed);
    } catch (error, stackTrace) {
      return ChartExportDeliveryResult.failure(
        file: file,
        error: error,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
    }
  }

  static Future<ChartExportDeliveryBatchResult> deliverBatch(
    ChartExportBatchResult batch,
    ChartExportDeliveryAdapter adapter, {
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
    ChartExportDeliveryBatchOptions batchOptions =
        const ChartExportDeliveryBatchOptions(),
  }) async {
    final results = <ChartExportDeliveryResult>[];
    for (final result in batch.results) {
      final delivery = await deliverResult(
        result,
        adapter,
        timeout: timeout ?? batchOptions.timeout,
        cancellationToken: cancellationToken ?? batchOptions.cancellationToken,
      );
      results.add(delivery);
      _emitBatchProgress(
        batchOptions,
        ChartExportDeliveryBatchProgress(
          completed: results.length,
          total: batch.results.length,
          result: delivery,
        ),
      );
      if (batchOptions.stopOnFirstFailure && !delivery.success) break;
    }
    return ChartExportDeliveryBatchResult(results);
  }

  static Future<ChartExportDeliveryBatchResult> deliverFiles(
    Iterable<ChartExportFile> files,
    ChartExportDeliveryAdapter adapter, {
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
    ChartExportDeliveryBatchOptions batchOptions =
        const ChartExportDeliveryBatchOptions(),
  }) async {
    final fileList = List<ChartExportFile>.unmodifiable(files);
    final results = <ChartExportDeliveryResult>[];
    for (final file in fileList) {
      final delivery = await deliverFile(
        file,
        adapter,
        timeout: timeout ?? batchOptions.timeout,
        cancellationToken: cancellationToken ?? batchOptions.cancellationToken,
      );
      results.add(delivery);
      _emitBatchProgress(
        batchOptions,
        ChartExportDeliveryBatchProgress(
          completed: results.length,
          total: fileList.length,
          result: delivery,
        ),
      );
      if (batchOptions.stopOnFirstFailure && !delivery.success) break;
    }
    return ChartExportDeliveryBatchResult(results);
  }

  static Future<ChartExportDeliveryResult> exportAndDeliver(
    ChartExportRequest request,
    ChartExportDeliveryAdapter adapter, {
    Duration? deliveryTimeout,
    ChartExportCancellationToken? deliveryCancellationToken,
  }) async {
    final result = await ChartExporter.export(request);
    return deliverResult(
      result,
      adapter,
      timeout: deliveryTimeout,
      cancellationToken: deliveryCancellationToken,
    );
  }

  static Future<ChartExportDeliveryBatchResult> exportAllAndDeliver(
    Iterable<ChartExportRequest> requests,
    ChartExportDeliveryAdapter adapter, {
    Duration? deliveryTimeout,
    ChartExportCancellationToken? deliveryCancellationToken,
    ChartExportBatchOptions exportBatchOptions =
        const ChartExportBatchOptions(),
    ChartExportDeliveryBatchOptions deliveryBatchOptions =
        const ChartExportDeliveryBatchOptions(),
  }) async {
    final batch = await ChartExporter.exportAll(
      requests,
      options: exportBatchOptions,
    );
    return deliverBatch(
      batch,
      adapter,
      timeout: deliveryTimeout,
      cancellationToken: deliveryCancellationToken,
      batchOptions: deliveryBatchOptions,
    );
  }

  static void _emitBatchProgress(
    ChartExportDeliveryBatchOptions options,
    ChartExportDeliveryBatchProgress progress,
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
    ChartExportDeliveryBatchOptions options,
    Object error,
    StackTrace stackTrace,
    ChartExportDeliveryBatchProgress progress,
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

  static Future<ChartExportDeliveryResult> _guardDelivery(
    Future<ChartExportDeliveryResult> Function() operation,
    ChartExportFile file, {
    Duration? timeout,
    ChartExportCancellationToken? cancellationToken,
  }) {
    if (timeout != null && timeout.inMicroseconds <= 0) {
      return Future.value(_timeoutDeliveryResult(file, timeout));
    }

    Future<ChartExportDeliveryResult> guarded = operation();
    if (timeout != null) {
      guarded = guarded.timeout(
        timeout,
        onTimeout: () => _timeoutDeliveryResult(file, timeout),
      );
    }

    final token = cancellationToken;
    if (token == null) return guarded;
    if (token.isCancelled) {
      return Future.value(_cancelledDeliveryResult(file, token));
    }

    return Future.any([
      guarded,
      token.whenCancelled.then((_) => _cancelledDeliveryResult(file, token)),
    ]);
  }

  static ChartExportDeliveryResult _cancelledDeliveryResult(
    ChartExportFile file,
    ChartExportCancellationToken? token,
  ) {
    return ChartExportDeliveryResult.failure(
      file: file,
      error: token?.reason ?? 'Delivery cancelled.',
    );
  }

  static ChartExportDeliveryResult _timeoutDeliveryResult(
    ChartExportFile file,
    Duration timeout,
  ) {
    return ChartExportDeliveryResult.failure(
      file: file,
      error: 'Delivery timed out after ${_formatDuration(timeout)}.',
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
}
