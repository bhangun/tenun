import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  test('normalizes export results into delivery files', () {
    final textResult = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'sales.csv',
      text: 'A,B\n1,2',
    );

    final textFile = ChartExportFile.fromResult(textResult);
    expect(textFile.filename, 'sales.csv');
    expect(textFile.mimeType, ChartExporter.csvMimeType);
    expect(textFile.format, ChartExportFormat.csv);
    expect(textFile.extension, 'csv');
    expect(textFile.isText, isTrue);
    expect(textFile.isBinary, isFalse);
    expect(utf8.decode(textFile.bytes), 'A,B\n1,2');
    expect(textFile.dataUri, startsWith('data:text/csv;base64,'));
    expect(textFile.contentDisposition(), 'attachment; filename="sales.csv"');
    expect(textFile.toMetadataJson()['sizeBytes'], textFile.sizeBytes);
    expect(
      textFile.toMetadataJson(includePayload: true)['base64'],
      textFile.base64Payload,
    );

    final binaryResult = ChartExportResult.bytes(
      format: ChartExportFormat.xlsx,
      filename: 'report.xlsx',
      bytes: Uint8List.fromList([0x50, 0x4b, 0x01]),
    );
    final binaryFile = ChartExportFile.fromResult(binaryResult);
    expect(binaryFile.filename, 'report.xlsx');
    expect(binaryFile.extension, 'xlsx');
    expect(binaryFile.isText, isFalse);
    expect(binaryFile.isBinary, isTrue);
    expect(binaryFile.base64Payload, 'UEsB');
  });

  test('delivery files sanitize unsafe filenames', () {
    final unsafeResult = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: '../CON.csv',
      text: 'A,B',
    );
    final file = ChartExportFile.fromResult(unsafeResult);

    expect(file.filename, 'CON_export.csv');
    expect(file.extension, 'csv');
    expect(file.metadata['filename'], '../CON.csv');
    expect(file.contentDisposition(), 'attachment; filename="CON_export.csv"');

    final directFile = ChartExportFile(
      filename: 'reports/Quarter:1?.xlsx',
      mimeType: ChartExporter.xlsxMimeType,
      bytes: Uint8List.fromList([0x50, 0x4b]),
    );
    expect(directFile.filename, 'reports_Quarter_1.xlsx');
  });

  test('callback adapter delivers files and reports failures', () async {
    final delivered = <ChartExportFile>[];
    final adapter = ChartExportCallbackDeliveryAdapter.save(
      onFile: delivered.add,
    );
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'sales.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    expect(adapter.intent, ChartExportDeliveryIntent.save);
    expect(delivery.success, isTrue);
    expect(delivery.filename, 'sales.csv');
    expect(delivery.sizeBytes, greaterThan(0));
    expect(delivery.duration, isNotNull);
    expect(delivery.toMetadataJson()['durationMicros'], isA<int>());
    expect(delivered.single.filename, 'sales.csv');

    final failingAdapter = ChartExportCallbackDeliveryAdapter.share(
      onFile: (_) => throw StateError('share failed'),
    );
    final failed = await ChartExportDelivery.deliverResult(
      result,
      failingAdapter,
    );
    expect(failingAdapter.intent, ChartExportDeliveryIntent.share);
    expect(failed.success, isFalse);
    expect(failed.errorText, contains('share failed'));
    expect(failed.toMetadataJson()['error'], contains('share failed'));
  });

  test('dry-run adapter validates delivery without side effects', () async {
    final adapter = ChartExportDelivery.dryRun(
      intent: ChartExportDeliveryIntent.share,
    );
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'preview.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    final metadata = delivery.toMetadataJson()['metadata'] as Map;

    expect(adapter, isA<ChartExportDryRunDeliveryAdapter>());
    expect(delivery.success, isTrue);
    expect(delivery.filename, 'preview.csv');
    expect(metadata['adapter'], 'dryRun');
    expect(metadata['intent'], 'share');
    expect(metadata['sideEffects'], isFalse);
  });

  test('composite adapter fans out delivery to multiple adapters', () async {
    final memory = ChartExportMemoryDeliveryAdapter(
      intent: ChartExportDeliveryIntent.save,
    );
    final shared = <String>[];
    final adapter = ChartExportDelivery.chain([
      memory,
      ChartExportCallbackDeliveryAdapter.share(
        onFile: (file) => shared.add(file.filename),
      ),
    ]);
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'fanout.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    final metadata = delivery.toMetadataJson()['metadata'] as Map;

    expect(adapter, isA<ChartExportCompositeDeliveryAdapter>());
    expect(delivery.success, isTrue);
    expect(memory.files.single.filename, 'fanout.csv');
    expect(shared, ['fanout.csv']);
    expect(metadata['adapter'], 'composite');
    expect(metadata['adapterCount'], 2);
    expect(metadata['attemptedAdapterCount'], 2);
    expect(metadata['successCount'], 2);
    expect(metadata['failureCount'], 0);
  });

  test('composite adapter can stop on the first failed delegate', () async {
    var skipped = false;
    final adapter = ChartExportDelivery.chain([
      ChartExportCallbackDeliveryAdapter.save(
        onFile: (_) => throw StateError('disk full'),
      ),
      ChartExportCallbackDeliveryAdapter.share(
        onFile: (_) {
          skipped = true;
        },
      ),
    ]);
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'stop.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    final metadata = delivery.toMetadataJson()['metadata'] as Map;

    expect(delivery.success, isFalse);
    expect(delivery.errorText, contains('adapter 1/2'));
    expect(delivery.errorText, contains('disk full'));
    expect(skipped, isFalse);
    expect(metadata['attemptedAdapterCount'], 1);
    expect(metadata['failureCount'], 1);
  });

  test('composite adapter can continue after failed delegates', () async {
    final memory = ChartExportMemoryDeliveryAdapter();
    final adapter = ChartExportDelivery.chain([
      ChartExportCallbackDeliveryAdapter.download(
        onFile: (_) => throw StateError('browser blocked download'),
      ),
      memory,
    ], stopOnFirstFailure: false);
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'continue.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    final metadata = delivery.toMetadataJson()['metadata'] as Map;

    expect(delivery.success, isFalse);
    expect(delivery.errorText, contains('1 of 2 adapters'));
    expect(memory.files.single.filename, 'continue.csv');
    expect(metadata['attemptedAdapterCount'], 2);
    expect(metadata['successCount'], 1);
    expect(metadata['failureCount'], 1);
  });

  test('retry adapter succeeds after transient failures', () async {
    var attempts = 0;
    final delegate = ChartExportCallbackDeliveryAdapter.save(
      onFile: (_) {
        attempts++;
        if (attempts < 3) {
          throw StateError('transient $attempts');
        }
      },
    );
    final adapter = ChartExportDelivery.withRetry(delegate, maxAttempts: 3);
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'retry.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    expect(delivery.success, isTrue);
    expect(delivery.attempts, 3);
    expect(delivery.retryErrors, hasLength(2));
    expect(delivery.retryErrors.first, contains('transient 1'));
    expect(delivery.filename, 'retry.csv');
  });

  test('retry adapter reports final failure after max attempts', () async {
    var attempts = 0;
    final delegate = ChartExportCallbackDeliveryAdapter.share(
      onFile: (_) {
        attempts++;
        throw StateError('still failing $attempts');
      },
    );
    final adapter = ChartExportRetryDeliveryAdapter(
      delegate: delegate,
      maxAttempts: 2,
    );
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'failed.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    expect(delivery.success, isFalse);
    expect(delivery.attempts, 2);
    expect(delivery.retryErrors, hasLength(2));
    expect(delivery.errorText, contains('still failing 2'));
    expect(attempts, 2);
  });

  test('retry adapter can stop retries through predicate', () async {
    var attempts = 0;
    final delegate = ChartExportCallbackDeliveryAdapter(
      onFile: (_) {
        attempts++;
        throw StateError('do not retry');
      },
    );
    final adapter = ChartExportRetryDeliveryAdapter(
      delegate: delegate,
      maxAttempts: 3,
      shouldRetry: (_, _, _) => false,
    );
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'once.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(result, adapter);
    expect(delivery.success, isFalse);
    expect(delivery.attempts, 1);
    expect(delivery.retryErrors, hasLength(1));
    expect(attempts, 1);
  });

  test('batch delivery preserves export failures', () async {
    final batch = ChartExportBatchResult([
      ChartExportResult.text(
        format: ChartExportFormat.csv,
        filename: 'ok.csv',
        text: 'A,B',
      ),
      ChartExportResult.failure(
        format: ChartExportFormat.png,
        filename: 'bad.png',
        error: 'No repaint boundary.',
      ),
    ]);
    final adapter = ChartExportMemoryDeliveryAdapter(
      intent: ChartExportDeliveryIntent.download,
    );

    final delivery = await ChartExportDelivery.deliverBatch(batch, adapter);
    expect(adapter.intent, ChartExportDeliveryIntent.download);
    expect(delivery.success, isFalse);
    expect(delivery.hasFailures, isTrue);
    expect(delivery.successCount, 1);
    expect(delivery.outputCount, 1);
    expect(delivery.failureCount, 1);
    expect(delivery.issueCount, 1);
    expect(delivery.hasOutput, isTrue);
    expect(delivery.files.single.filename, 'ok.csv');
    expect(adapter.files.single.filename, 'ok.csv');
    expect(delivery.failed.single.errorText, 'No repaint boundary.');
    expect(delivery.hasIssues, isTrue);
    expect(delivery.issueMessages.single, contains('Delivery failed'));
    expect(delivery.issueMessages.single, contains('bad.png'));
    expect(delivery.primaryIssue, contains('No repaint boundary'));
    expect(delivery.summaryText(), '1 of 2 deliveries failed');
    expect(delivery.toMetadataJson()['hasIssues'], isTrue);
    expect(delivery.toMetadataJson()['primaryIssue'], contains('bad.png'));
    expect(delivery.toMetadataJson()['issues'], isA<List<Object?>>());
  });

  test(
    'batch delivery reports progress and can stop on first failure',
    () async {
      final batch = ChartExportBatchResult([
        ChartExportResult.text(
          format: ChartExportFormat.csv,
          filename: 'ok.csv',
          text: 'A,B',
        ),
        ChartExportResult.failure(
          format: ChartExportFormat.png,
          filename: 'bad.png',
          error: 'No repaint boundary.',
        ),
        ChartExportResult.text(
          format: ChartExportFormat.csv,
          filename: 'skipped.csv',
          text: 'C,D',
        ),
      ]);
      final adapter = ChartExportMemoryDeliveryAdapter();
      final progress = <ChartExportDeliveryBatchProgress>[];

      final delivery = await ChartExportDelivery.deliverBatch(
        batch,
        adapter,
        batchOptions: ChartExportDeliveryBatchOptions(
          stopOnFirstFailure: true,
          onProgress: progress.add,
        ),
      );

      expect(delivery.results, hasLength(2));
      expect(delivery.success, isFalse);
      expect(delivery.successCount, 1);
      expect(delivery.failureCount, 1);
      expect(adapter.files.map((file) => file.filename), ['ok.csv']);
      expect(progress.map((item) => item.completed), [1, 2]);
      expect(progress.map((item) => item.total), [3, 3]);
      expect(progress.last.result.errorText, 'No repaint boundary.');
      expect(progress.last.toMetadataJson()['fraction'], closeTo(2 / 3, 0.001));
    },
  );

  test(
    'batch delivery progress callback errors fail fast by default',
    () async {
      final batch = ChartExportBatchResult([
        ChartExportResult.text(
          format: ChartExportFormat.csv,
          filename: 'a.csv',
          text: 'A,B',
        ),
        ChartExportResult.text(
          format: ChartExportFormat.csv,
          filename: 'b.csv',
          text: 'C,D',
        ),
      ]);
      final adapter = ChartExportMemoryDeliveryAdapter();
      var progressCalls = 0;

      await expectLater(
        ChartExportDelivery.deliverBatch(
          batch,
          adapter,
          batchOptions: ChartExportDeliveryBatchOptions(
            onProgress: (_) {
              progressCalls++;
              throw StateError('delivery progress failed');
            },
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(progressCalls, 1);
      expect(adapter.files.map((file) => file.filename), ['a.csv']);
    },
  );

  test('batch delivery can continue after progress callback errors', () async {
    final batch = ChartExportBatchResult([
      ChartExportResult.text(
        format: ChartExportFormat.csv,
        filename: 'a.csv',
        text: 'A,B',
      ),
      ChartExportResult.text(
        format: ChartExportFormat.csv,
        filename: 'b.csv',
        text: 'C,D',
      ),
    ]);
    final adapter = ChartExportMemoryDeliveryAdapter();
    final progress = <ChartExportDeliveryBatchProgress>[];
    final errors = <String>[];

    final delivery = await ChartExportDelivery.deliverBatch(
      batch,
      adapter,
      batchOptions: ChartExportDeliveryBatchOptions(
        continueOnProgressError: true,
        onProgress: (item) {
          progress.add(item);
          if (item.completed == 1) {
            throw StateError('delivery progress failed');
          }
        },
        onProgressError: (error, _, item) {
          errors.add('${item.completed}:$error');
        },
      ),
    );

    expect(delivery.success, isTrue);
    expect(delivery.successCount, 2);
    expect(adapter.files.map((file) => file.filename), ['a.csv', 'b.csv']);
    expect(progress.map((item) => item.completed), [1, 2]);
    expect(errors, hasLength(1));
    expect(errors.single, contains('delivery progress failed'));
  });

  test('batch delivery retries each file independently', () async {
    final attemptsByFile = <String, int>{};
    final delegate = ChartExportCallbackDeliveryAdapter.download(
      onFile: (file) {
        final attempts = (attemptsByFile[file.filename] ?? 0) + 1;
        attemptsByFile[file.filename] = attempts;
        if (attempts == 1) {
          throw StateError('temporary ${file.filename}');
        }
      },
    );
    final adapter = ChartExportRetryDeliveryAdapter(
      delegate: delegate,
      maxAttempts: 2,
    );
    final batch = ChartExportBatchResult([
      ChartExportResult.text(
        format: ChartExportFormat.csv,
        filename: 'a.csv',
        text: 'A,B',
      ),
      ChartExportResult.text(
        format: ChartExportFormat.csv,
        filename: 'b.csv',
        text: 'C,D',
      ),
    ]);

    final delivery = await ChartExportDelivery.deliverBatch(batch, adapter);
    expect(delivery.success, isTrue);
    expect(delivery.successCount, 2);
    expect(delivery.results.map((result) => result.attempts), [2, 2]);
    expect(delivery.results.first.retryErrors.single, contains('temporary a'));
    expect(attemptsByFile, {'a.csv': 2, 'b.csv': 2});
  });

  test('delivery supports timeout without starting adapter work', () async {
    var attempts = 0;
    final adapter = ChartExportCallbackDeliveryAdapter.save(
      onFile: (_) {
        attempts++;
      },
    );
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'timeout.csv',
      text: 'A,B',
    );

    final delivery = await ChartExportDelivery.deliverResult(
      result,
      adapter,
      timeout: Duration.zero,
    );
    expect(delivery.success, isFalse);
    expect(delivery.errorText, contains('timed out'));
    expect(delivery.filename, 'timeout.csv');
    expect(attempts, 0);
  });

  test('delivery supports cancellation before and during work', () async {
    var attempts = 0;
    final adapter = ChartExportCallbackDeliveryAdapter.share(
      onFile: (_) async {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      },
    );
    final result = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'cancel.csv',
      text: 'A,B',
    );

    final preCancelled = ChartExportCancellationToken()..cancel('No delivery.');
    final skipped = await ChartExportDelivery.deliverResult(
      result,
      adapter,
      cancellationToken: preCancelled,
    );
    expect(skipped.success, isFalse);
    expect(skipped.errorText, 'No delivery.');
    expect(attempts, 0);

    final runningToken = ChartExportCancellationToken();
    final future = ChartExportDelivery.deliverResult(
      result,
      adapter,
      cancellationToken: runningToken,
    );
    runningToken.cancel('Delivery stopped.');
    final cancelled = await future;
    expect(cancelled.success, isFalse);
    expect(cancelled.errorText, 'Delivery stopped.');
    expect(attempts, 1);
  });

  test('exports and delivers request batches', () async {
    final config = _DeliveryTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );
    final adapter = ChartExportMemoryDeliveryAdapter();

    final delivery = await ChartExportDelivery.exportAllAndDeliver([
      ChartExportRequest.csv(
        config: config,
        categoryLabels: const ['Jan', 'Feb'],
        filename: 'sales',
        lineEnding: '\n',
      ),
      ChartExportRequest.xlsx(
        config: config,
        categoryLabels: const ['Jan', 'Feb'],
        filename: 'sales',
      ),
    ], adapter);

    expect(delivery.success, isTrue);
    expect(delivery.successCount, 2);
    expect(delivery.totalSizeBytes, greaterThan(500));
    expect(adapter.files.map((file) => file.filename), [
      'sales.csv',
      'sales.xlsx',
    ]);
    expect(adapter.files.first.text, contains('Jan,10'));

    final manifestFile = ChartExportManifest.deliveryBatchFile(
      delivery,
      createdAt: DateTime.utc(2026, 6, 5),
      pretty: false,
    );
    final manifest = jsonDecode(manifestFile.text!) as Map<String, dynamic>;
    expect(manifestFile.filename, 'chart_delivery_manifest.json');
    expect(manifestFile.mimeType, ChartExportManifest.mimeType);
    expect(manifestFile.metadata['createdAt'], '2026-06-05T00:00:00.000Z');
    expect(manifest['kind'], 'chartExportDeliveryBatch');
    expect((manifest['batch'] as Map<String, dynamic>)['successCount'], 2);

    final archiveFile = ChartExportArchive.deliveryBatchZip(
      delivery,
      filename: 'delivery_bundle',
      createdAt: DateTime.utc(2026, 6, 5),
    );
    expect(archiveFile.filename, 'delivery_bundle.zip');
    expect(archiveFile.mimeType, ChartExportArchive.mimeType);
    expect(archiveFile.isBinary, isTrue);
    expect(archiveFile.metadata['kind'], 'chartExportArchive');
    expect(archiveFile.metadata['source'], 'deliveryBatch');
    expect(archiveFile.metadata['fileCount'], 3);
    final archiveText = latin1.decode(archiveFile.bytes);
    expect(archiveText, contains('sales.csv'));
    expect(archiveText, contains('sales.xlsx'));
    expect(archiveText, contains('manifest.json'));
    expect(archiveText, contains('chartExportDeliveryBatch'));

    adapter.clear();
    expect(adapter.files, isEmpty);
  });
}

class _DeliveryTestConfig extends BaseChartConfig {
  _DeliveryTestConfig({required super.series}) : super(type: ChartType.line);

  @override
  Widget buildChart() => const SizedBox.shrink();
}
