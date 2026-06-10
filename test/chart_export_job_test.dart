import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  test('plans export jobs before running them', () {
    final plan = ChartExportJobOptions(
      formats: const [
        ChartExportFormat.csv,
        ChartExportFormat.xlsx,
        ChartExportFormat.png,
      ],
      config: _jobConfig(),
      filename: 'planned',
      skipUnavailable: true,
      deliverExports: true,
      createArchive: true,
      deliverArchive: true,
    ).buildPlan();

    expect(plan.requestedCount, 3);
    expect(plan.availableCount, 2);
    expect(plan.unavailableCount, 1);
    expect(plan.runCount, 2);
    expect(plan.skippedUnavailableCount, 1);
    expect(plan.exportableFormats, [
      ChartExportFormat.csv,
      ChartExportFormat.xlsx,
    ]);
    expect(plan.willCreateArchive, isTrue);
    expect(plan.willDeliverExports, isFalse);
    expect(plan.willDeliverArchive, isFalse);
    expect(plan.estimatedDeliveryCount, 0);
    expect(plan.canRun, isTrue);
    expect(plan.hasBlockers, isFalse);
    expect(plan.issueCount, 2);
    expect(plan.warningIssues.map((issue) => issue.code), [
      'export_delivery_missing_adapter',
      'archive_delivery_missing_adapter',
    ]);
    expect(plan.warnings, hasLength(2));
    expect(plan.summaryText(), contains('3 exports planned'));
    expect(plan.summaryText(), contains('1 unavailable skipped'));

    final metadata = plan.toMetadataJson();
    expect(metadata['requestedCount'], 3);
    expect(metadata['runCount'], 2);
    expect(metadata['canRun'], isTrue);
    expect(metadata['warningCount'], 2);
    expect(metadata['blockerCount'], 0);
    expect(metadata['formats'], ['csv', 'xlsx', 'png']);
    expect(metadata['exportableFormats'], ['csv', 'xlsx']);
    expect(metadata['issues'], isA<List<Object?>>());
    expect(metadata['skippedUnavailable'], isA<List<Object?>>());
  });

  test('plans risky unavailable exports when skipping is disabled', () {
    final plan = ChartExportJobOptions(
      formats: const [ChartExportFormat.png],
      config: _jobConfig(),
      skipUnavailable: false,
    ).buildPlan();

    expect(plan.runCount, 1);
    expect(plan.skippedUnavailableCount, 0);
    expect(plan.willAttemptUnavailable, isTrue);
    expect(plan.warnings.single, contains('will be attempted and may fail'));
    expect(plan.warningIssues.single.code, 'unavailable_format_will_run');
    expect(plan.canRun, isTrue);
    expect(plan.summaryText(), contains('1 unavailable will run'));
  });

  test('reports blocking preflight issues when no requests can run', () {
    final emptyPlan = ChartExportJobOptions(
      formats: const [],
      config: _jobConfig(),
    ).buildPlan();

    expect(emptyPlan.canRun, isFalse);
    expect(emptyPlan.hasBlockers, isTrue);
    expect(emptyPlan.blockers.single.code, 'no_requests');
    expect(emptyPlan.diagnosticsText(), contains('No export requests'));
    expect(emptyPlan.toMetadataJson()['canRun'], isFalse);
    expect(emptyPlan.toMetadataJson()['blockerCount'], 1);

    final skippedPlan = ChartExportJobOptions(
      formats: const [ChartExportFormat.png],
      config: _jobConfig(),
      skipUnavailable: true,
    ).buildPlan();

    expect(skippedPlan.requestedCount, 1);
    expect(skippedPlan.runCount, 0);
    expect(skippedPlan.skippedUnavailableCount, 1);
    expect(skippedPlan.canRun, isFalse);
    expect(skippedPlan.hasBlockers, isTrue);
    expect(skippedPlan.blockers.single.code, 'no_runnable_exports');
    expect(skippedPlan.warnings.single, contains('every configured format'));
    expect(skippedPlan.toMetadataJson()['blockers'], isA<List<Object?>>());
  });

  test('preflight treats invalid request options as unavailable', () async {
    final invalidRequests = [
      ChartExportRequest.csv(
        config: _jobConfig(),
        filename: 'bad_csv',
        delimiter: '',
      ),
      ChartExportRequest.png(
        boundaryKey: GlobalKey(),
        filename: 'bad_png',
        pixelRatio: 0,
      ),
    ];
    final plan = ChartExportJobOptions(
      requests: invalidRequests,
      skipUnavailable: true,
    ).buildPlan();

    expect(plan.requestedCount, 2);
    expect(plan.availableCount, 0);
    expect(plan.unavailableCount, 2);
    expect(plan.runCount, 0);
    expect(plan.skippedUnavailableCount, 2);
    expect(plan.canRun, isFalse);
    expect(plan.blockers.single.code, 'no_runnable_exports');
    expect(
      plan.skippedUnavailable.map((item) => item.capability.disabledReason),
      [contains('delimiter'), contains('pixelRatio')],
    );

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(requests: invalidRequests, skipUnavailable: true),
    );

    expect(result.preflightBlocked, isTrue);
    expect(result.exportBatch.results, isEmpty);
    expect(result.exportBatch.skippedUnavailableCount, 2);
    expect(result.primaryIssue, contains('No export requests can run'));
  });

  test('blocks jobs with preflight blockers by default', () async {
    final progress = <ChartExportJobProgress>[];

    final emptyResult = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [],
        config: _jobConfig(),
        onProgress: progress.add,
      ),
    );

    expect(emptyResult.preflightBlocked, isTrue);
    expect(emptyResult.completed, isFalse);
    expect(emptyResult.success, isFalse);
    expect(emptyResult.status, ChartExportJobStatus.failed);
    expect(emptyResult.plan?.blockers.single.code, 'no_requests');
    expect(emptyResult.exportBatch.requestedCount, 0);
    expect(emptyResult.exportBatch.results, isEmpty);
    expect(emptyResult.primaryIssue, contains('No export requests'));
    expect(emptyResult.timing, isNotNull);
    expect(emptyResult.stageDurations, isEmpty);
    expect(progress.single.stage, ChartExportJobStage.completed);
    expect(emptyResult.toMetadataJson()['preflightBlocked'], isTrue);

    final skippedResult = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.png],
        config: _jobConfig(),
        skipUnavailable: true,
      ),
    );

    expect(skippedResult.preflightBlocked, isTrue);
    expect(skippedResult.status, ChartExportJobStatus.failed);
    expect(skippedResult.plan?.blockers.single.code, 'no_runnable_exports');
    expect(skippedResult.exportBatch.requestedCount, 1);
    expect(skippedResult.exportBatch.skippedUnavailableCount, 1);
    expect(skippedResult.issueMessages, contains(contains('every configured')));
  });

  test('can continue with preflight blockers in warn-only mode', () async {
    var batchReady = false;
    final stages = <ChartExportJobStage>[];

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.png],
        config: _jobConfig(),
        skipUnavailable: true,
        preflightPolicy: ChartExportJobPreflightPolicy.warnOnly,
        onProgress: (progress) => stages.add(progress.stage),
        onExportBatchReady: (batch) {
          batchReady = true;
          expect(batch.skippedUnavailableCount, 1);
        },
      ),
    );

    expect(result.preflightBlocked, isFalse);
    expect(result.completed, isTrue);
    expect(result.success, isFalse);
    expect(result.status, ChartExportJobStatus.completedWithIssues);
    expect(result.plan?.canRun, isFalse);
    expect(result.exportBatch.skippedUnavailableCount, 1);
    expect(result.warnings.single, contains('every configured format'));
    expect(batchReady, isTrue);
    expect(stages, contains(ChartExportJobStage.exporting));
    expect(stages.last, ChartExportJobStage.completed);
    expect(result.toMetadataJson()['preflightBlocked'], isFalse);
  });

  test('summarizes job timing metadata', () {
    final timing = ChartExportJobTiming(
      startedAt: DateTime.utc(2026, 1, 1),
      endedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      duration: const Duration(seconds: 1),
      stageDurations: const {
        ChartExportJobStage.exporting: Duration(milliseconds: 120),
        ChartExportJobStage.delivering: Duration(milliseconds: 300),
      },
    );

    expect(timing.durationMicros, 1000000);
    expect(timing.durationMs, 1000);
    expect(timing.slowestStage, ChartExportJobStage.delivering);
    expect(
      timing.stageDuration(ChartExportJobStage.exporting),
      const Duration(milliseconds: 120),
    );
    expect(timing.summaryText(), contains('job 1.0s'));
    expect(timing.summaryText(), contains('delivering 300ms'));

    final metadata = timing.toMetadataJson();
    expect(metadata['startedAt'], '2026-01-01T00:00:00.000Z');
    expect(metadata['endedAt'], '2026-01-01T00:00:01.000Z');
    expect(metadata['slowestStage'], 'delivering');
    expect(metadata['stageDurationsMicros'], containsPair('exporting', 120000));
  });

  test('runs export jobs with archive and delivery orchestration', () async {
    final adapter = ChartExportMemoryDeliveryAdapter(
      intent: ChartExportDeliveryIntent.download,
    );
    final stages = <ChartExportJobStage>[];
    final exportProgress = <ChartExportBatchProgress>[];
    final deliveryProgress = <ChartExportDeliveryBatchProgress>[];
    final jobEvents = <ChartExportJobEvent>[];

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [
          ChartExportFormat.csv,
          ChartExportFormat.xlsx,
          ChartExportFormat.png,
        ],
        config: _jobConfig(),
        categoryLabels: const ['Jan', 'Feb'],
        filename: 'job',
        skipUnavailable: true,
        deliverExports: true,
        createArchive: true,
        deliverArchive: true,
        deliveryAdapter: adapter,
        onProgress: (progress) => stages.add(progress.stage),
        onExportProgress: exportProgress.add,
        onDeliveryProgress: deliveryProgress.add,
        onEvent: jobEvents.add,
      ),
    );

    expect(result.completed, isTrue);
    expect(result.success, isFalse);
    expect(result.status, ChartExportJobStatus.completedWithIssues);
    expect(result.isCompletedWithIssues, isTrue);
    expect(result.hasOutput, isTrue);
    expect(result.hasIssues, isTrue);
    expect(result.issueCount, 1);
    expect(result.plan?.requestedCount, 3);
    expect(result.plan?.runCount, 2);
    expect(result.exportBatch.requestedCount, 3);
    expect(result.exportBatch.outputCount, 2);
    expect(result.exportBatch.skippedUnavailableCount, 1);
    expect(result.exportDelivery?.successCount, 2);
    expect(result.archive?.filename, 'job.zip');
    expect(result.archiveDelivery?.success, isTrue);
    expect(result.successfulExports.map((item) => item.filename), [
      'job.csv',
      'job.xlsx',
    ]);
    expect(result.failedExports, isEmpty);
    expect(result.exportFiles.map((file) => file.filename), [
      'job.csv',
      'job.xlsx',
    ]);
    expect(result.outputFilenames, ['job.csv', 'job.xlsx', 'job.zip']);
    expect(result.exportResultFor(ChartExportFormat.csv)?.filename, 'job.csv');
    expect(result.exportFileFor(ChartExportFormat.xlsx)?.filename, 'job.xlsx');
    expect(result.outputFileNamed('job.zip')?.mimeType, 'application/zip');
    expect(result.hasEvents, isTrue);
    expect(result.events, hasLength(jobEvents.length));
    expect(
      result.events.map((event) => event.type),
      containsAll([
        ChartExportJobEventType.planned,
        ChartExportJobEventType.started,
        ChartExportJobEventType.exported,
        ChartExportJobEventType.archived,
        ChartExportJobEventType.delivered,
        ChartExportJobEventType.completed,
      ]),
    );
    expect(
      result.eventsOfType(ChartExportJobEventType.completed).single.status,
      ChartExportJobStatus.completedWithIssues,
    );
    expect(result.lastEvent?.type, ChartExportJobEventType.completed);
    expect(result.summaryText(), contains('1 unavailable format skipped'));
    expect(result.issueMessages.single, contains('png export skipped'));
    expect(result.primaryIssue, contains('png export skipped'));
    expect(result.toMetadataJson()['status'], 'completedWithIssues');
    expect(result.toMetadataJson()['issueCount'], 1);
    expect(result.toMetadataJson()['outputFilenames'], [
      'job.csv',
      'job.xlsx',
      'job.zip',
    ]);
    expect(result.toMetadataJson()['events'], isA<List<Object?>>());
    expect(result.timing, isNotNull);
    expect(result.duration, result.timing!.duration);
    expect(result.stageDuration(ChartExportJobStage.exporting), isNotNull);
    expect(result.stageDuration(ChartExportJobStage.archiving), isNotNull);
    expect(result.stageDuration(ChartExportJobStage.delivering), isNotNull);
    expect(result.summaryText(includeTiming: true), contains('job '));

    final timingMetadata =
        result.toMetadataJson()['timing'] as Map<String, Object?>;
    expect(timingMetadata['startedAt'], isA<String>());
    expect(timingMetadata['endedAt'], isA<String>());
    expect(timingMetadata['durationMicros'], isA<int>());
    expect(
      timingMetadata['stageDurationsMicros'],
      containsPair('exporting', isA<int>()),
    );

    expect(exportProgress, hasLength(2));
    expect(deliveryProgress, hasLength(2));
    expect(
      stages,
      containsAll(<ChartExportJobStage>[
        ChartExportJobStage.exporting,
        ChartExportJobStage.archiving,
        ChartExportJobStage.delivering,
        ChartExportJobStage.completed,
      ]),
    );
    expect(stages.last, ChartExportJobStage.completed);

    final deliveredNames = adapter.files.map((file) => file.filename).toList();
    expect(deliveredNames, containsAll(['job.csv', 'job.xlsx', 'job.zip']));

    final archiveText = utf8.decode(
      result.archive!.bytes,
      allowMalformed: true,
    );
    expect(archiveText, contains('job.csv'));
    expect(archiveText, contains('job.xlsx'));
    expect(archiveText, contains('manifest.json'));
    expect(archiveText, contains('chartExportBatch'));

    final manifestMetadata = ChartExportJobManifest.metadata(
      result,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(manifestMetadata['kind'], ChartExportJobManifest.kind);
    expect(manifestMetadata['createdAt'], '2026-01-01T00:00:00.000Z');
    expect(
      manifestMetadata['summary'],
      containsPair('status', 'completedWithIssues'),
    );
    expect(
      manifestMetadata['summary'],
      containsPair('outputFilenames', ['job.csv', 'job.xlsx', 'job.zip']),
    );
    expect(manifestMetadata['job'], isA<Map<String, Object?>>());
    expect(manifestMetadata['outputs'], isA<List<Object?>>());
    expect(manifestMetadata['outputs'], hasLength(3));
    final manifestJob = manifestMetadata['job'] as Map<String, Object?>;
    expect(manifestJob['events'], isA<List<Object?>>());

    final manifestJson = ChartExportJobManifest.json(
      result,
      createdAt: DateTime.utc(2026, 1, 1),
      pretty: false,
    );
    expect(manifestJson, contains('"kind":"chartExportJob"'));
    expect(manifestJson, contains('"outputFilenames"'));

    final manifestFile = ChartExportJobManifest.file(
      result,
      filename: 'job_manifest',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(manifestFile.filename, 'job_manifest.json');
    expect(manifestFile.mimeType, ChartExportJobManifest.mimeType);
    expect(manifestFile.text, contains('"chartExportJob"'));
    expect(manifestFile.metadata['kind'], ChartExportJobManifest.kind);
  });

  test('notifies when the export batch is ready before delivery', () async {
    final events = <String>[];
    final adapter = ChartExportCallbackDeliveryAdapter.save(
      onFile: (file) => events.add('deliver:${file.filename}'),
    );

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.csv],
        config: _jobConfig(),
        filename: 'ready_hook',
        deliverExports: true,
        deliveryAdapter: adapter,
        onExportBatchReady: (batch) {
          events.add('ready:${batch.successCount}');
          expect(batch.successCount, 1);
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.exportDelivery?.successCount, 1);
    expect(events, ['ready:1', 'deliver:ready_hook.csv']);
  });

  test('isolates callback errors by default and reports warnings', () async {
    var progressCalls = 0;
    final callbackErrors = <ChartExportJobCallbackError>[];

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.csv],
        config: _jobConfig(),
        filename: 'callback_guard',
        onProgress: (progress) {
          progressCalls++;
          if (progressCalls == 1) {
            throw StateError('progress observer failed');
          }
        },
        onCallbackError: callbackErrors.add,
      ),
    );

    expect(result.completed, isTrue);
    expect(result.success, isFalse);
    expect(result.status, ChartExportJobStatus.completedWithIssues);
    expect(result.exportBatch.successCount, 1);
    expect(result.warnings.single, contains('onProgress'));
    expect(result.primaryIssue, contains('progress observer failed'));
    expect(callbackErrors, hasLength(1));
    expect(callbackErrors.single.callbackName, 'onProgress');
    expect(callbackErrors.single.stage, ChartExportJobStage.exporting);
    expect(
      callbackErrors.single.toMetadataJson()['message'],
      contains('onProgress'),
    );
  });

  test('isolates async export batch ready callback errors', () async {
    final callbackErrors = <ChartExportJobCallbackError>[];

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.csv],
        config: _jobConfig(),
        filename: 'batch_ready_guard',
        onExportBatchReady: (batch) async {
          expect(batch.successCount, 1);
          throw StateError('ready hook failed');
        },
        onCallbackError: callbackErrors.add,
      ),
    );

    expect(result.completed, isTrue);
    expect(result.success, isFalse);
    expect(result.status, ChartExportJobStatus.completedWithIssues);
    expect(result.exportBatch.successCount, 1);
    expect(result.warnings.single, contains('onExportBatchReady'));
    expect(result.primaryIssue, contains('ready hook failed'));
    expect(callbackErrors.single.callbackName, 'onExportBatchReady');
  });

  test('can fail fast on callback errors when configured', () async {
    final controller = ChartExportJobController();

    await expectLater(
      controller.run(
        ChartExportJobOptions(
          formats: const [ChartExportFormat.csv],
          config: _jobConfig(),
          filename: 'callback_fail_fast',
          continueOnCallbackError: false,
          onProgress: (progress) {
            throw StateError('observer should abort');
          },
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(controller.isRunning, isFalse);
  });

  test('reports missing delivery adapters as job warnings', () async {
    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.csv],
        config: _jobConfig(),
        filename: 'warnings',
        deliverExports: true,
        createArchive: true,
        deliverArchive: true,
      ),
    );

    expect(result.completed, isTrue);
    expect(result.success, isFalse);
    expect(result.exportBatch.successCount, 1);
    expect(result.archive?.filename, 'warnings.zip');
    expect(result.exportDelivery, isNull);
    expect(result.archiveDelivery, isNull);
    expect(result.warnings, hasLength(2));
    expect(result.warnings.first, contains('no delivery adapter'));
    expect(result.summaryText(), contains('delivery skipped'));
    expect(
      result.toMetadataJson()['warnings'],
      contains(
        'Archive delivery skipped because no delivery adapter was provided.',
      ),
    );
  });

  test('supports explicit requests for direct chart export usage', () async {
    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        requests: const [
          ChartExportRequest.csvRows(
            rows: [
              ['Category', 'Value'],
              ['A', 10],
              ['B', 20],
            ],
            filename: 'direct_rows',
            lineEnding: '\n',
          ),
        ],
      ),
    );

    expect(result.success, isTrue);
    expect(result.status, ChartExportJobStatus.succeeded);
    expect(result.isSucceeded, isTrue);
    expect(result.issueMessages, isEmpty);
    expect(result.primaryIssue, isNull);
    expect(result.exportBatch.successCount, 1);
    expect(result.exportBatch.successful.single.filename, 'direct_rows.csv');
    expect(result.exportBatch.successful.single.text, contains('A,10'));
    expect(result.toMetadataJson()['status'], 'succeeded');
  });

  test('passes cancellation through the full job pipeline', () async {
    final token = ChartExportCancellationToken();
    token.cancel('Stop job.');

    final result = await ChartExportJobController().run(
      ChartExportJobOptions(
        formats: const [ChartExportFormat.csv],
        config: _jobConfig(),
        filename: 'cancelled',
        cancellationToken: token,
        createArchive: true,
      ),
    );

    expect(result.completed, isFalse);
    expect(result.success, isFalse);
    expect(result.status, ChartExportJobStatus.cancelled);
    expect(result.isCancelled, isTrue);
    expect(result.cancellationReason, 'Stop job.');
    expect(result.archive, isNull);
    expect(result.exportBatch.failed.single.error, 'Stop job.');
    expect(result.warnings, isEmpty);
    expect(result.issueMessages, contains('Stop job.'));
    expect(result.toMetadataJson()['cancelled'], isTrue);
    expect(result.toMetadataJson()['cancellationReason'], 'Stop job.');
    expect(result.summaryText(), contains('1 of 1 export failed'));
  });

  test(
    'reports failed status and issue messages for delivery failures',
    () async {
      final result = await ChartExportJobController().run(
        ChartExportJobOptions(
          formats: const [ChartExportFormat.csv],
          config: _jobConfig(),
          filename: 'delivery_failure',
          deliverExports: true,
          deliveryAdapter: ChartExportCallbackDeliveryAdapter.save(
            onFile: (file) => throw StateError('No disk space.'),
          ),
        ),
      );

      expect(result.completed, isFalse);
      expect(result.success, isFalse);
      expect(result.status, ChartExportJobStatus.failed);
      expect(result.isFailed, isTrue);
      expect(result.exportBatch.successCount, 1);
      expect(result.exportDelivery?.failureCount, 1);
      expect(result.primaryIssue, contains('Delivery failed'));
      expect(result.issueMessages.single, contains('No disk space'));

      final metadata = result.toMetadataJson();
      expect(metadata['status'], 'failed');
      expect(metadata['failed'], isTrue);
      expect(metadata['primaryIssue'], contains('Delivery failed'));
      expect(metadata['issues'], isA<List<Object?>>());
    },
  );
}

_JobTestConfig _jobConfig() {
  return _JobTestConfig(
    series: [
      Series(type: ChartType.line, name: 'Revenue', data: [12, 18]),
      Series(type: ChartType.bar, name: 'Cost', data: [7, 9]),
    ],
  );
}

class _JobTestConfig extends BaseChartConfig {
  _JobTestConfig({required super.series}) : super(type: ChartType.line);

  @override
  Widget buildChart() => const SizedBox.shrink();
}
