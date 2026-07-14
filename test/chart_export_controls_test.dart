import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  testWidgets('ChartExportControls exports CSV and reports result', (
    tester,
  ) async {
    final results = [];
    final jobPlans = <ChartExportJobPlan>[];
    final jobProgress = <ChartExportJobProgress>[];
    final jobs = <ChartExportJobResult>[];
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv],
            categoryLabels: const ['Jan', 'Feb'],
            filename: 'sales',
            copyTextExportsToClipboard: false,
            onResult: results.add,
            onExportJobPlan: jobPlans.add,
            onExportJobProgress: jobProgress.add,
            onExportJobResult: jobs.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(results, hasLength(1));
    expect(results.single.success, isTrue);
    expect(results.single.filename, 'sales.csv');
    expect(results.single.mimeType, ChartExporter.csvMimeType);
    expect(results.single.text, contains('Category,Sales'));
    expect(results.single.text, contains('Jan,10'));
    expect(jobPlans, hasLength(1));
    expect(jobPlans.single.requestedCount, 1);
    expect(jobPlans.single.willDeliverExports, isFalse);
    expect(jobs, hasLength(1));
    expect(jobs.single.exportBatch.successCount, 1);
    expect(jobs.single.exportDelivery, isNull);
    expect(
      jobProgress.map((item) => item.stage),
      containsAll([
        ChartExportJobStage.exporting,
        ChartExportJobStage.completed,
      ]),
    );
    expect(find.textContaining('sales.csv ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls can deliver exported files', (tester) async {
    final deliveries = <ChartExportDeliveryResult>[];
    final jobPlans = <ChartExportJobPlan>[];
    final jobs = <ChartExportJobResult>[];
    final adapter = ChartExportMemoryDeliveryAdapter(
      intent: ChartExportDeliveryIntent.save,
    );
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv],
            categoryLabels: const ['Jan', 'Feb'],
            filename: 'sales',
            copyTextExportsToClipboard: false,
            deliveryAdapter: adapter,
            onDeliveryResult: deliveries.add,
            onExportJobPlan: jobPlans.add,
            onExportJobResult: jobs.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(deliveries, hasLength(1));
    expect(deliveries.single.success, isTrue);
    expect(deliveries.single.filename, 'sales.csv');
    expect(adapter.files.single.filename, 'sales.csv');
    expect(adapter.files.single.text, contains('Jan,10'));
    expect(jobPlans.single.willDeliverExports, isTrue);
    expect(jobPlans.single.estimatedDeliveryCount, 1);
    expect(jobs.single.exportDelivery?.successCount, 1);
    expect(find.textContaining('sales.csv delivered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls shows live job progress while busy', (
    tester,
  ) async {
    final deliveryGate = Completer<void>();
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv],
            filename: 'live_progress',
            copyTextExportsToClipboard: false,
            deliveryAdapter: ChartExportCallbackDeliveryAdapter.save(
              onFile: (_) => deliveryGate.future,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Delivering 1 export file. (0/1)'),
      findsOneWidget,
    );

    deliveryGate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('live_progress.csv delivered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls can cancel an active export job', (
    tester,
  ) async {
    final deliveryGate = Completer<void>();
    final deliveries = <ChartExportDeliveryResult>[];
    final jobs = <ChartExportJobResult>[];
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv],
            filename: 'cancel_me',
            copyTextExportsToClipboard: false,
            showCancelButton: true,
            cancelExportReason: 'User cancelled from test.',
            deliveryAdapter: ChartExportCallbackDeliveryAdapter.save(
              onFile: (_) => deliveryGate.future,
            ),
            onDeliveryResult: deliveries.add,
            onExportJobResult: jobs.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    expect(
      find.textContaining('Delivering 1 export file. (0/1)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    expect(deliveries, hasLength(1));
    expect(deliveries.single.success, isFalse);
    expect(deliveries.single.errorText, 'User cancelled from test.');
    expect(jobs, hasLength(1));
    expect(jobs.single.completed, isFalse);
    expect(jobs.single.exportDelivery?.failureCount, 1);
    expect(find.textContaining('Delivery failed'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    final csvButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'CSV'),
    );
    expect(csvButton.onPressed, isNotNull);

    deliveryGate.complete();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ChartExportControls reports callback errors without sticking busy',
    (tester) async {
      final errors = <Object>[];
      var resultCallbacks = 0;
      final config = _ExportControlsTestConfig(
        series: [
          Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartExportControls(
              config: config,
              formats: const [ChartExportFormat.csv],
              filename: 'callback_error',
              copyTextExportsToClipboard: false,
              onResult: (_) {
                resultCallbacks++;
                throw StateError('result callback failed');
              },
              onError: (error, _) => errors.add(error),
            ),
          ),
        ),
      );

      await tester.tap(find.text('CSV'));
      await tester.pump();
      await tester.pump();

      expect(resultCallbacks, 1);
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('result callback failed'));
      expect(find.textContaining('Export control error'), findsOneWidget);
      final csvButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'CSV'),
      );
      expect(csvButton.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ChartExportControls reports export and delivery timeouts', (
    tester,
  ) async {
    final exportResults = <ChartExportResult>[];
    final deliveryResults = <ChartExportDeliveryResult>[];
    var deliveryAttempts = 0;
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv],
            filename: 'timeout_export',
            copyTextExportsToClipboard: false,
            exportTimeout: Duration.zero,
            onResult: exportResults.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(exportResults.single.success, isFalse);
    expect(exportResults.single.error, contains('timed out'));
    expect(find.textContaining('Export failed'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv],
            filename: 'timeout_delivery',
            copyTextExportsToClipboard: false,
            deliveryTimeout: Duration.zero,
            deliveryAdapter: ChartExportCallbackDeliveryAdapter.save(
              onFile: (_) {
                deliveryAttempts++;
              },
            ),
            onDeliveryResult: deliveryResults.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(deliveryResults.single.success, isFalse);
    expect(deliveryResults.single.errorText, contains('timed out'));
    expect(deliveryAttempts, 0);
    expect(find.textContaining('Delivery failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls disables formats missing required inputs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            formats: [ChartExportFormat.csv, ChartExportFormat.png],
            copyTextExportsToClipboard: false,
          ),
        ),
      ),
    );

    final csvButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'CSV'),
    );
    final pngButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'PNG'),
    );

    expect(csvButton.onPressed, isNull);
    expect(pngButton.onPressed, isNull);
    expect(
      find.byTooltip(
        'CSV export requires a chart config, JSON payload, or rows.',
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip('PNG export requires a repaint boundary key.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls shows preflight diagnostics', (
    tester,
  ) async {
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.png],
            copyTextExportsToClipboard: false,
          ),
        ),
      ),
    );

    final pngButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'PNG'),
    );
    expect(pngButton.onPressed, isNull);
    expect(find.textContaining('Export unavailable'), findsOneWidget);
    expect(find.textContaining('every configured format'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls can hide preflight diagnostics', (
    tester,
  ) async {
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.png],
            copyTextExportsToClipboard: false,
            showPreflightDiagnostics: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('Export unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls exports data from raw JSON payload only', (
    tester,
  ) async {
    final results = <ChartExportResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            jsonConfig: const {
              'type': 'barRace',
              'categories': ['Alpha', 'Beta'],
              'frameLabels': ['2026'],
              'frames': [
                [14, 24],
              ],
            },
            formats: const [ChartExportFormat.csv],
            filename: 'race_payload',
            copyTextExportsToClipboard: false,
            onResult: results.add,
          ),
        ),
      ),
    );

    final csvButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'CSV'),
    );
    expect(csvButton.onPressed, isNotNull);

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(results, hasLength(1));
    expect(results.single.success, isTrue);
    expect(results.single.text, contains('Frame,Category,Value'));
    expect(results.single.text, contains('2026,Alpha,14'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls batch exports available formats', (
    tester,
  ) async {
    final started = <List<ChartExportFormat>>[];
    final progress = <ChartExportBatchProgress>[];
    final results = <ChartExportResult>[];
    final batches = <ChartExportBatchResult>[];
    final batchPlans = <ChartExportJobPlan>[];
    final batchJobProgress = <ChartExportJobProgress>[];
    final batchJobs = <ChartExportJobResult>[];
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [
              ChartExportFormat.csv,
              ChartExportFormat.xlsx,
              ChartExportFormat.png,
            ],
            categoryLabels: const ['Jan', 'Feb'],
            filename: 'bundle',
            copyTextExportsToClipboard: false,
            onResult: results.add,
            onBatchStarted: started.add,
            onBatchProgress: progress.add,
            onBatchResult: batches.add,
            onBatchJobPlan: batchPlans.add,
            onBatchJobProgress: batchJobProgress.add,
            onBatchJobResult: batchJobs.add,
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    final pngButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'PNG'),
    );
    expect(pngButton.onPressed, isNull);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump();

    expect(started, [
      [ChartExportFormat.csv, ChartExportFormat.xlsx],
    ]);
    expect(batchPlans, hasLength(1));
    expect(batchPlans.single.requestedCount, 2);
    expect(batchPlans.single.willDeliverExports, isFalse);
    expect(batchPlans.single.willCreateArchive, isFalse);
    expect(results, hasLength(2));
    expect(results.map((result) => result.format), [
      ChartExportFormat.csv,
      ChartExportFormat.xlsx,
    ]);
    expect(progress.map((item) => item.completed), [1, 2]);
    expect(progress.map((item) => item.total), [2, 2]);
    expect(progress.last.isComplete, isTrue);
    expect(batches, hasLength(1));
    expect(batches.single.success, isTrue);
    expect(batches.single.successCount, 2);
    expect(batchJobs, hasLength(1));
    expect(batchJobs.single.exportBatch.successCount, 2);
    expect(batchJobs.single.exportDelivery, isNull);
    expect(
      batchJobProgress.map((item) => item.stage),
      containsAll([
        ChartExportJobStage.exporting,
        ChartExportJobStage.completed,
      ]),
    );
    expect(
      batches.single.resultFor(ChartExportFormat.csv)?.filename,
      'bundle.csv',
    );
    expect(
      batches.single.resultFor(ChartExportFormat.csv)?.text,
      contains('Jan,10'),
    );
    expect(
      batches.single.resultFor(ChartExportFormat.xlsx)?.filename,
      'bundle.xlsx',
    );
    expect(find.textContaining('2 exports ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ChartExportControls keeps batch running when progress callback throws',
    (tester) async {
      final errors = <Object>[];
      final batches = <ChartExportBatchResult>[];
      final config = _ExportControlsTestConfig(
        series: [
          Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartExportControls(
              config: config,
              formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
              filename: 'progress_error',
              copyTextExportsToClipboard: false,
              onBatchProgress: (_) {
                throw StateError('progress callback failed');
              },
              onBatchResult: batches.add,
              onError: (error, _) => errors.add(error),
            ),
          ),
        ),
      );

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump();

      expect(errors, isNotEmpty);
      expect(errors.first.toString(), contains('progress callback failed'));
      expect(batches, hasLength(1));
      expect(batches.single.successCount, 2);
      expect(find.textContaining('Export control error'), findsOneWidget);
      final allButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'All'),
      );
      expect(allButton.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ChartExportControls batch delivers available formats', (
    tester,
  ) async {
    final deliveries = <ChartExportDeliveryBatchResult>[];
    final deliveryProgress = <ChartExportDeliveryBatchProgress>[];
    final batchPlans = <ChartExportJobPlan>[];
    final batchJobs = <ChartExportJobResult>[];
    final adapter = ChartExportMemoryDeliveryAdapter(
      intent: ChartExportDeliveryIntent.download,
    );
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
            categoryLabels: const ['Jan', 'Feb'],
            filename: 'bundle',
            copyTextExportsToClipboard: false,
            deliveryAdapter: adapter,
            onBatchJobPlan: batchPlans.add,
            onBatchJobResult: batchJobs.add,
            onDeliveryBatchProgress: deliveryProgress.add,
            onDeliveryBatchResult: deliveries.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump();

    expect(batchPlans, hasLength(1));
    expect(batchPlans.single.willDeliverExports, isTrue);
    expect(batchPlans.single.estimatedDeliveryCount, 2);
    expect(batchJobs, hasLength(1));
    expect(batchJobs.single.exportDelivery?.successCount, 2);
    expect(deliveries, hasLength(1));
    expect(deliveries.single.success, isTrue);
    expect(deliveries.single.successCount, 2);
    expect(deliveryProgress.map((item) => item.completed), [1, 2]);
    expect(deliveryProgress.map((item) => item.total), [2, 2]);
    expect(deliveryProgress.last.isComplete, isTrue);
    expect(adapter.files.map((file) => file.filename), [
      'bundle.csv',
      'bundle.xlsx',
    ]);
    expect(find.textContaining('2 files delivered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChartExportControls exports and delivers ZIP archives', (
    tester,
  ) async {
    final archiveStarted = <List<ChartExportFormat>>[];
    final archivePlans = <ChartExportJobPlan>[];
    final archiveJobProgress = <ChartExportJobProgress>[];
    final archiveJobs = <ChartExportJobResult>[];
    final batches = <ChartExportBatchResult>[];
    final archives = <ChartExportFile>[];
    final archiveDeliveries = <ChartExportDeliveryResult>[];
    final adapter = ChartExportMemoryDeliveryAdapter(
      intent: ChartExportDeliveryIntent.download,
    );
    final config = _ExportControlsTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: const [10, 20]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartExportControls(
            config: config,
            formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
            categoryLabels: const ['Jan', 'Feb'],
            filename: 'bundle',
            copyTextExportsToClipboard: false,
            showArchiveExportButton: true,
            archiveExportLabel: 'Bundle ZIP',
            deliveryAdapter: adapter,
            onArchiveStarted: archiveStarted.add,
            onArchiveJobPlan: archivePlans.add,
            onArchiveJobProgress: archiveJobProgress.add,
            onArchiveJobResult: archiveJobs.add,
            onBatchResult: batches.add,
            onArchiveResult: archives.add,
            onArchiveDeliveryResult: archiveDeliveries.add,
          ),
        ),
      ),
    );

    expect(find.text('Bundle ZIP'), findsOneWidget);

    await tester.tap(find.text('Bundle ZIP'));
    await tester.pump();
    await tester.pump();

    expect(archiveStarted, [
      [ChartExportFormat.csv, ChartExportFormat.xlsx],
    ]);
    expect(archivePlans, hasLength(1));
    expect(archivePlans.single.requestedCount, 2);
    expect(archivePlans.single.willCreateArchive, isTrue);
    expect(archivePlans.single.willDeliverArchive, isTrue);
    expect(archivePlans.single.estimatedDeliveryCount, 1);
    expect(
      archiveJobProgress.map((item) => item.stage),
      containsAll([
        ChartExportJobStage.exporting,
        ChartExportJobStage.archiving,
        ChartExportJobStage.delivering,
        ChartExportJobStage.completed,
      ]),
    );
    expect(archiveJobs, hasLength(1));
    expect(archiveJobs.single.archive?.filename, 'bundle.zip');
    expect(batches, hasLength(1));
    expect(batches.single.success, isTrue);
    expect(archives, hasLength(1));
    expect(archives.single.filename, 'bundle.zip');
    expect(archives.single.mimeType, ChartExportArchive.mimeType);
    expect(archiveDeliveries, hasLength(1));
    expect(archiveDeliveries.single.success, isTrue);
    expect(archiveDeliveries.single.filename, 'bundle.zip');
    expect(adapter.files, hasLength(1));
    expect(adapter.files.single.filename, 'bundle.zip');

    final archiveText = latin1.decode(adapter.files.single.bytes);
    expect(archiveText, contains('bundle.csv'));
    expect(archiveText, contains('bundle.xlsx'));
    expect(archiveText, contains('manifest.json'));
    expect(archiveText, contains('chartExportBatch'));
    expect(find.textContaining('bundle.zip delivered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('ExportableChartController exposes its managed boundary key', () {
    final controller = ExportableChartController();

    expect(controller.boundaryKey, isA<GlobalKey>());
  });

  testWidgets('ExportableTenunChart exports JSON-driven chart data', (
    tester,
  ) async {
    final snapshot = ChartRegistry.snapshot();
    allChartsBundle.register();
    addTearDown(() => ChartRegistry.restore(snapshot));

    final results = <ChartExportResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: ExportableTenunChart(
              jsonConfig: const {
                'type': 'line',
                'xAxis': {
                  'data': ['Jan', 'Feb'],
                },
                'series': [
                  {
                    'name': 'Revenue',
                    'data': [12, 18],
                  },
                ],
              },
              formats: const [ChartExportFormat.csv],
              categoryLabels: const ['Jan', 'Feb'],
              filename: 'json_revenue',
              copyTextExportsToClipboard: false,
              onExportResult: results.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(results, hasLength(1));
    expect(results.single.success, isTrue);
    expect(results.single.filename, 'json_revenue.csv');
    expect(results.single.text, contains('Category,Revenue'));
    expect(results.single.text, contains('Jan,12'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExportableTenunChart forwards export delivery callbacks', (
    tester,
  ) async {
    final snapshot = ChartRegistry.snapshot();
    allChartsBundle.register();
    addTearDown(() => ChartRegistry.restore(snapshot));

    final adapter = ChartExportMemoryDeliveryAdapter();
    final deliveries = <ChartExportDeliveryResult>[];
    final jobs = <ChartExportJobResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: ExportableTenunChart(
              jsonConfig: const {
                'type': 'line',
                'xAxis': {
                  'data': ['Jan'],
                },
                'series': [
                  {
                    'name': 'Revenue',
                    'data': [12],
                  },
                ],
              },
              formats: const [ChartExportFormat.csv],
              filename: 'json_delivery',
              copyTextExportsToClipboard: false,
              exportDeliveryAdapter: adapter,
              onExportJobResult: jobs.add,
              onExportDeliveryResult: deliveries.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('CSV'));
    await tester.pump();
    await tester.pump();

    expect(deliveries, hasLength(1));
    expect(deliveries.single.success, isTrue);
    expect(deliveries.single.filename, 'json_delivery.csv');
    expect(jobs.single.exportDelivery?.successCount, 1);
    expect(adapter.files.single.filename, 'json_delivery.csv');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExportableTenunChart forwards archive export callbacks', (
    tester,
  ) async {
    final snapshot = ChartRegistry.snapshot();
    allChartsBundle.register();
    addTearDown(() => ChartRegistry.restore(snapshot));

    final adapter = ChartExportMemoryDeliveryAdapter();
    final archives = <ChartExportFile>[];
    final deliveries = <ChartExportDeliveryResult>[];
    final archiveJobs = <ChartExportJobResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: ExportableTenunChart(
              jsonConfig: const {
                'type': 'line',
                'xAxis': {
                  'data': ['Jan', 'Feb'],
                },
                'series': [
                  {
                    'name': 'Revenue',
                    'data': [12, 18],
                  },
                ],
              },
              formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
              categoryLabels: const ['Jan', 'Feb'],
              filename: 'json_archive',
              copyTextExportsToClipboard: false,
              showArchiveExportButton: true,
              archiveExportLabel: 'Archive',
              exportDeliveryAdapter: adapter,
              onArchiveExportJobResult: archiveJobs.add,
              onArchiveExportResult: archives.add,
              onArchiveExportDeliveryResult: deliveries.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Archive'));
    await tester.pump();
    await tester.pump();

    expect(archives, hasLength(1));
    expect(archiveJobs.single.archive?.filename, 'json_archive.zip');
    expect(archives.single.filename, 'json_archive.zip');
    expect(deliveries, hasLength(1));
    expect(deliveries.single.filename, 'json_archive.zip');
    expect(adapter.files.single.filename, 'json_archive.zip');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExportableTenunChart can show a fallback for invalid JSON', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportableTenunChart(
            jsonConfig: const {'type': 'definitely-not-registered'},
            catchRenderErrors: true,
            errorBuilder: (context, error) => const Text('custom fallback'),
          ),
        ),
      ),
    );

    expect(find.text('custom fallback'), findsOneWidget);
    expect(find.text('CSV'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ExportControlsTestConfig extends BaseChartConfig {
  _ExportControlsTestConfig({required super.series})
    : super(type: ChartType.line);

  @override
  Widget buildChart() => const SizedBox.shrink();
}
