import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  test('exports chart data as rows and CSV', () {
    final config = _ExportTestConfig(
      series: [
        Series(
          type: ChartType.line,
          name: 'Revenue, "A"',
          data: [
            1,
            2.5,
            {'value': 3},
            [4, 5],
            double.nan,
          ],
        ),
        Series(type: ChartType.bar, name: 'Cost', data: [true, null, 'x']),
      ],
    );

    final rows = ChartExporter.toRows(
      config,
      categoryLabels: ['Jan', 'Q"2', 'Mar'],
    );
    expect(rows.first, ['Category', 'Revenue, "A"', 'Cost']);
    expect(rows[1], ['Jan', 1, true]);
    expect(rows[2], ['Q"2', 2.5, null]);
    expect(rows[3], ['Mar', 3, 'x']);
    expect(rows[4], [3, '[4,5]', null]);

    final csv = ChartExporter.toCsv(
      config,
      categoryLabels: ['Jan', 'Q"2', 'Mar'],
      lineEnding: '\n',
    );
    expect(csv, contains('Category,"Revenue, ""A""",Cost'));
    expect(csv, contains('Jan,1,true'));
    expect(csv, contains('"Q""2",2.5,'));
    expect(csv, contains('Mar,3,x'));
    expect(csv, contains('3,"[4,5]",'));
  });

  test('exports raw JSON payloads as rows', () {
    final barRaceRows = ChartExporter.rowsFromPayload({
      'frames': [
        {
          'label': '2025',
          'values': {'Alpha': 10, 'Beta': 20},
        },
      ],
    });
    expect(barRaceRows, [
      ['Frame', 'Category', 'Value'],
      ['2025', 'Alpha', 10],
      ['2025', 'Beta', 20],
    ]);

    final flowRows = ChartExporter.rowsFromPayload({
      'nodes': [
        {'id': 'A'},
        {'id': 'B'},
      ],
      'links': [
        {'source': 'A', 'target': 'B', 'value': 5},
      ],
    });
    expect(flowRows, [
      ['Kind', 'Id', 'Name', 'Source', 'Target', 'Value'],
      ['node', 'A', 'A', '', '', null],
      ['node', 'B', 'B', '', '', null],
      ['link', '', '', 'A', 'B', 5],
    ]);

    final hierarchyRows = ChartExporter.rowsFromPayload({
      'root': {
        'name': 'All',
        'children': [
          {'name': 'A', 'value': 2},
        ],
      },
    });
    expect(hierarchyRows, [
      ['Path', 'Name', 'Parent', 'Depth', 'Value'],
      ['All', 'All', '', 0, null],
      ['All / A', 'A', 'All', 1, 2],
    ]);

    final seriesRows = ChartExporter.rowsFromPayload(
      {
        'series': [
          {
            'name': 'Revenue',
            'data': [10, 20],
          },
        ],
      },
      categoryLabels: ['Q1', 'Q2'],
    );
    expect(seriesRows, [
      ['Category', 'Revenue'],
      ['Q1', 10],
      ['Q2', 20],
    ]);
  });

  test('exports chart data as a valid-looking XLSX container', () {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Revenue, "A"', data: [1, 2.5]),
      ],
    );

    final xlsx = ChartExporter.toXlsx(
      config,
      categoryLabels: ['Q"1', 'Q2'],
      sheetName: 'Revenue/Q1*Bad?Name',
    );

    expect(xlsx.length, greaterThan(500));
    expect(xlsx[0], 0x50);
    expect(xlsx[1], 0x4b);
    final text = latin1.decode(xlsx);
    expect(text, contains('[Content_Types].xml'));
    expect(text, contains('xl/worksheets/sheet1.xml'));
    expect(text, contains('Revenue Q1 Bad Name'));
    expect(text, contains('Revenue, &quot;A&quot;'));
    expect(text, contains('Q&quot;1'));
    expect(text, contains('<v>2.5</v>'));
  });

  test('writes dependency-free ZIP archives with safe unique entries', () {
    final zip = ChartZipStoreWriter.writeFiles([
      ChartZipStoreFile(
        name: '_rels/.rels',
        bytes: Uint8List.fromList(utf8.encode('<rels/>')),
      ),
      ChartZipStoreFile(
        name: '../Report?.csv',
        bytes: Uint8List.fromList(utf8.encode('A,B\n1,2')),
      ),
      ChartZipStoreFile(
        name: 'Report?.csv',
        bytes: Uint8List.fromList(utf8.encode('C,D\n3,4')),
      ),
    ]);

    expect(zip[0], 0x50);
    expect(zip[1], 0x4b);
    final text = latin1.decode(zip);
    expect(text, contains('_rels/.rels'));
    expect(text, contains('Report_.csv'));
    expect(text, contains('Report_2.csv'));
    expect(text, contains('A,B\n1,2'));
    expect(text, contains('C,D\n3,4'));
  });

  test('exports chart data through unified request results', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );

    final csvResult = await ChartExporter.export(
      ChartExportRequest.csv(
        config: config,
        categoryLabels: ['A', 'B'],
        filename: 'sales',
        lineEnding: '\n',
      ),
    );
    expect(csvResult.success, isTrue);
    expect(csvResult.isText, isTrue);
    expect(csvResult.isBinary, isFalse);
    expect(csvResult.mimeType, ChartExporter.csvMimeType);
    expect(csvResult.filename, 'sales.csv');
    expect(csvResult.text, contains('Sales'));
    expect(csvResult.sizeBytes, greaterThan(0));
    expect(csvResult.duration, isNotNull);
    expect(csvResult.toMetadataJson()['durationMicros'], isA<int>());

    final xlsxResult = await ChartExporter.export(
      ChartExportRequest.xlsx(
        config: config,
        categoryLabels: ['A', 'B'],
        filename: 'sales.xlsx',
      ),
    );
    expect(xlsxResult.success, isTrue);
    expect(xlsxResult.isBinary, isTrue);
    expect(xlsxResult.mimeType, ChartExporter.xlsxMimeType);
    expect(xlsxResult.filename, 'sales.xlsx');
    expect(xlsxResult.bytes, isNotNull);
    expect(xlsxResult.bytes!.first, 0x50);

    final failure = await ChartExporter.export(
      const ChartExportRequest(format: ChartExportFormat.csv),
    );
    expect(failure.success, isFalse);
    expect(failure.error, contains('requires a chart config'));
    expect(failure.filename, 'chart_export.csv');
  });

  test('export requests validate unsafe option values', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );

    final invalidCsv = await ChartExporter.export(
      ChartExportRequest.csv(
        config: config,
        filename: 'invalid',
        delimiter: '',
      ),
    );
    expect(invalidCsv.success, isFalse);
    expect(invalidCsv.error, contains('delimiter must not be empty'));
    expect(invalidCsv.filename, 'invalid.csv');

    final invalidPng = await ChartExporter.export(
      ChartExportRequest.png(
        boundaryKey: GlobalKey(),
        filename: 'invalid_image',
        pixelRatio: 0,
      ),
    );
    expect(invalidPng.success, isFalse);
    expect(invalidPng.error, contains('PNG export pixelRatio'));
    expect(invalidPng.error, contains('finite positive'));

    final invalidJpeg = await ChartExporter.export(
      ChartExportRequest.jpeg(
        boundaryKey: GlobalKey(),
        filename: 'invalid_image',
        pixelRatio: double.nan,
      ),
    );
    expect(invalidJpeg.success, isFalse);
    expect(invalidJpeg.error, contains('JPEG export pixelRatio'));
    expect(invalidJpeg.error, contains('finite positive'));
  });

  test('export filenames are sanitized and extension-safe', () async {
    expect(
      ChartExportFilename.withExtension('../Finance/Q2:Report?.csv', 'csv'),
      'Finance_Q2_Report.csv',
    );
    expect(ChartExportFilename.withExtension('CON', 'csv'), 'CON_export.csv');
    expect(
      ChartExportFilename.withExtension('report.xlsx', 'xlsx'),
      'report.xlsx',
    );
    expect(
      ChartExportFilename.withExtension('', 'csv', fallback: 'fallback.csv'),
      'fallback.csv',
    );
    final longName = ChartExportFilename.withExtension(
      'very long monthly revenue report',
      'csv',
      maxLength: 18,
    );
    expect(longName, endsWith('.csv'));
    expect(longName.length, lessThanOrEqualTo(18));

    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );
    final result = await ChartExporter.export(
      ChartExportRequest.csv(config: config, filename: '../CON?.csv'),
    );
    expect(result.success, isTrue);
    expect(result.filename, 'CON_export.csv');
  });

  test('export capabilities explain unavailable formats', () {
    final noInputs = ChartExportCapabilities.evaluate(
      formats: const [
        ChartExportFormat.csv,
        ChartExportFormat.png,
        ChartExportFormat.csv,
      ],
    );
    expect(noInputs.formats, [ChartExportFormat.csv, ChartExportFormat.png]);
    expect(noInputs.exportableFormats, isEmpty);
    expect(
      noInputs.disabledReason(ChartExportFormat.csv),
      contains('chart config'),
    );
    expect(
      noInputs.disabledReason(ChartExportFormat.png),
      contains('repaint boundary key'),
    );

    final dataOnly = ChartExportCapabilities.evaluate(
      formats: const [
        ChartExportFormat.csv,
        ChartExportFormat.xlsx,
        ChartExportFormat.png,
      ],
      rows: const [
        ['Category', 'Sales'],
        ['Jan', 10],
      ],
    );
    expect(dataOnly.canExport(ChartExportFormat.csv), isTrue);
    expect(dataOnly.canExport(ChartExportFormat.xlsx), isTrue);
    expect(dataOnly.canExport(ChartExportFormat.png), isFalse);
    expect(dataOnly.exportableFormats, [
      ChartExportFormat.csv,
      ChartExportFormat.xlsx,
    ]);

    final imageOnly = ChartExportCapabilities.evaluate(
      formats: const [ChartExportFormat.png, ChartExportFormat.jpeg],
      boundaryKey: GlobalKey(),
    );
    expect(imageOnly.exportableFormats, [
      ChartExportFormat.png,
      ChartExportFormat.jpeg,
    ]);
    expect(imageOnly.toMetadataJson()['unavailableFormats'], isEmpty);
  });

  test('export batches can skip unavailable formats', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );

    final exportableFormats = ChartExporter.exportableFormats(
      formats: const [
        ChartExportFormat.csv,
        ChartExportFormat.xlsx,
        ChartExportFormat.png,
        ChartExportFormat.jpeg,
      ],
      config: config,
    );
    expect(exportableFormats, [ChartExportFormat.csv, ChartExportFormat.xlsx]);

    final batch = await ChartExporter.exportFormats(
      formats: const [
        ChartExportFormat.csv,
        ChartExportFormat.png,
        ChartExportFormat.jpeg,
      ],
      config: config,
      categoryLabels: const ['Jan', 'Feb'],
      filename: 'skip_missing_image',
      batchOptions: const ChartExportBatchOptions(skipUnavailable: true),
    );

    expect(batch.success, isTrue);
    expect(batch.requestedCount, 3);
    expect(batch.results, hasLength(1));
    expect(batch.outputCount, 1);
    expect(batch.hasOutput, isTrue);
    expect(batch.skippedUnavailableCount, 2);
    expect(batch.notRunCount, 0);
    expect(batch.hasSkippedUnavailable, isTrue);
    expect(batch.hasIssues, isTrue);
    expect(batch.skippedUnavailable.map((item) => item.format), [
      ChartExportFormat.png,
      ChartExportFormat.jpeg,
    ]);
    expect(
      batch.skippedUnavailable.first.disabledReason,
      'PNG export requires a repaint boundary key.',
    );
    expect(
      batch.resultFor(ChartExportFormat.csv)?.filename,
      'skip_missing_image.csv',
    );
    expect(batch.resultFor(ChartExportFormat.png), isNull);
    expect(batch.resultFor(ChartExportFormat.jpeg), isNull);
    expect(batch.issueMessages, hasLength(2));
    expect(batch.primaryIssue, contains('png export skipped'));
    expect(batch.primaryIssue, contains('repaint boundary key'));

    final metadata = batch.toMetadataJson();
    expect(metadata['requestedCount'], 3);
    expect(metadata['count'], 1);
    expect(metadata['outputCount'], 1);
    expect(metadata['skippedUnavailableCount'], 2);
    expect(metadata['notRunCount'], 0);
    expect(metadata['issueCount'], 2);
    expect(metadata['hasOutput'], isTrue);
    expect(metadata['hasIssues'], isTrue);
    expect(metadata['completedWithoutOutput'], isFalse);
    expect(metadata['primaryIssue'], contains('png export skipped'));
    expect(metadata['issues'], isA<List<Object?>>());
    expect(metadata['skippedUnavailable'], isA<List<Object?>>());
    final skipped =
        (metadata['skippedUnavailable'] as List<Object?>).first
            as Map<String, dynamic>;
    expect(skipped['format'], 'png');
    expect(skipped['disabledReason'], contains('repaint boundary key'));

    final manifestFile = ChartExportManifest.exportBatchFile(
      batch,
      createdAt: DateTime.utc(2026, 6, 5),
      pretty: false,
    );
    final manifest = jsonDecode(manifestFile.text!) as Map<String, dynamic>;
    final manifestBatch = manifest['batch'] as Map<String, dynamic>;
    expect(manifestBatch['requestedCount'], 3);
    expect(manifestBatch['skippedUnavailableCount'], 2);

    final archiveFile = ChartExportArchive.exportBatchZip(batch);
    expect(archiveFile.metadata['sourceRequestedCount'], 3);
    expect(archiveFile.metadata['sourceSkippedUnavailableCount'], 2);
    expect(archiveFile.metadata['sourceNotRunCount'], 0);
    expect(archiveFile.metadata['sourceHasOutput'], isTrue);
    expect(archiveFile.metadata['sourceCompletedWithoutOutput'], isFalse);
    expect(batch.summaryText(), startsWith('1 export ready'));
    expect(batch.summaryText(), contains('2 unavailable formats skipped'));

    final directBatch = await ChartExporter.exportAll([
      ChartExportRequest.csv(config: config, filename: 'direct_skip'),
      const ChartExportRequest(
        format: ChartExportFormat.png,
        filename: 'direct_skip',
      ),
    ], options: const ChartExportBatchOptions(skipUnavailable: true));

    expect(directBatch.success, isTrue);
    expect(directBatch.requestedCount, 2);
    expect(directBatch.results, hasLength(1));
    expect(directBatch.skippedUnavailableCount, 1);
    expect(directBatch.notRunCount, 0);
    expect(
      directBatch.resultFor(ChartExportFormat.csv)?.filename,
      'direct_skip.csv',
    );

    final requestCapabilities = ChartExporter.capabilitiesForRequests([
      ChartExportRequest.csv(config: config, filename: 'direct_skip'),
      const ChartExportRequest(
        format: ChartExportFormat.png,
        filename: 'direct_skip',
      ),
    ]);
    expect(requestCapabilities.exportableFormats, [ChartExportFormat.csv]);
    expect(
      requestCapabilities.disabledReason(ChartExportFormat.png),
      contains('repaint boundary key'),
    );
  });

  test('request capabilities include unsafe option validation', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );

    final csvCapability = ChartExporter.capabilityForRequest(
      ChartExportRequest.csv(
        config: config,
        filename: 'bad_csv',
        delimiter: '',
      ),
    );
    expect(csvCapability.canExport, isFalse);
    expect(csvCapability.disabledReason, contains('delimiter'));

    final pngCapability = ChartExporter.capabilityForRequest(
      ChartExportRequest.png(
        boundaryKey: GlobalKey(),
        filename: 'bad_png',
        pixelRatio: 0,
      ),
    );
    expect(pngCapability.canExport, isFalse);
    expect(pngCapability.disabledReason, contains('pixelRatio'));

    final batch = await ChartExporter.exportAll([
      ChartExportRequest.csv(config: config, filename: 'valid'),
      ChartExportRequest.csv(
        config: config,
        filename: 'bad_csv',
        delimiter: '',
      ),
      ChartExportRequest.png(
        boundaryKey: GlobalKey(),
        filename: 'bad_png',
        pixelRatio: double.infinity,
      ),
    ], options: const ChartExportBatchOptions(skipUnavailable: true));

    expect(batch.success, isTrue);
    expect(batch.successCount, 1);
    expect(batch.skippedUnavailableCount, 2);
    expect(batch.skippedUnavailable.map((item) => item.disabledReason), [
      contains('delimiter'),
      contains('pixelRatio'),
    ]);
  });

  test('export batches report completed without output', () async {
    final batch = await ChartExporter.exportFormats(
      formats: const [ChartExportFormat.png, ChartExportFormat.jpeg],
      filename: 'images_only',
      batchOptions: const ChartExportBatchOptions(skipUnavailable: true),
    );

    expect(batch.success, isTrue);
    expect(batch.requestedCount, 2);
    expect(batch.results, isEmpty);
    expect(batch.outputCount, 0);
    expect(batch.hasOutput, isFalse);
    expect(batch.skippedUnavailableCount, 2);
    expect(batch.issueCount, 2);
    expect(batch.hasIssues, isTrue);
    expect(batch.completedWithoutOutput, isTrue);
    expect(
      batch.summaryText(),
      'No exports produced; 2 unavailable formats skipped',
    );

    final metadata = batch.toMetadataJson();
    expect(metadata['hasOutput'], isFalse);
    expect(metadata['completedWithoutOutput'], isTrue);

    final archiveFile = ChartExportArchive.exportBatchZip(batch);
    expect(archiveFile.metadata['sourceOutputCount'], 0);
    expect(archiveFile.metadata['sourceHasOutput'], isFalse);
    expect(archiveFile.metadata['sourceCompletedWithoutOutput'], isTrue);
    expect(archiveFile.metadata['fileCount'], 1);
    expect(latin1.decode(archiveFile.bytes), contains('manifest.json'));
  });

  test('export requests support timeout and cancellation', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );

    final timedOut = await ChartExporter.export(
      ChartExportRequest.csv(
        config: config,
        filename: 'timeout',
        timeout: Duration.zero,
      ),
    );
    expect(timedOut.success, isFalse);
    expect(timedOut.filename, 'timeout.csv');
    expect(timedOut.error, contains('timed out'));

    final token = ChartExportCancellationToken();
    token.cancel('User cancelled export.');
    final cancelled = await ChartExporter.export(
      ChartExportRequest.csv(
        config: config,
        filename: 'cancelled',
        cancellationToken: token,
      ),
    );
    expect(cancelled.success, isFalse);
    expect(cancelled.filename, 'cancelled.csv');
    expect(cancelled.error, 'User cancelled export.');

    final cancelledBatch = await ChartExporter.exportFormats(
      formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
      config: config,
      filename: 'batch_cancelled',
      cancellationToken: token,
    );
    expect(cancelledBatch.success, isFalse);
    expect(cancelledBatch.failureCount, 2);
    expect(cancelledBatch.failed.map((result) => result.error), [
      'User cancelled export.',
      'User cancelled export.',
    ]);
  });

  test('exports multiple formats as batch results', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );

    final batch = await ChartExporter.exportFormats(
      formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
      config: config,
      categoryLabels: const ['A', 'B'],
      filename: 'batch',
      sheetName: 'Batch Sheet',
      lineEnding: '\n',
    );

    expect(batch.success, isTrue);
    expect(batch.hasFailures, isFalse);
    expect(batch.successCount, 2);
    expect(batch.failureCount, 0);
    expect(batch.totalSizeBytes, greaterThan(500));
    expect(batch.successful, hasLength(2));
    expect(batch.failed, isEmpty);
    expect(batch.resultFor(ChartExportFormat.csv)?.filename, 'batch.csv');
    expect(batch.resultFor(ChartExportFormat.csv)?.text, contains('A,10'));
    expect(batch.resultFor(ChartExportFormat.xlsx)?.filename, 'batch.xlsx');
    expect(batch.resultFor(ChartExportFormat.xlsx)?.bytes?.first, 0x50);
    expect(batch.resultsFor(ChartExportFormat.csv), hasLength(1));

    final metadata = batch.toMetadataJson();
    expect(metadata['success'], isTrue);
    expect(metadata['count'], 2);
    expect(metadata['successCount'], 2);
    expect(metadata['failureCount'], 0);
    expect(metadata['totalSizeBytes'], batch.totalSizeBytes);
    expect(metadata['results'], isA<List<Object?>>());

    final manifestFile = ChartExportManifest.exportBatchFile(
      batch,
      createdAt: DateTime.utc(2026, 6, 5),
      pretty: false,
    );
    final manifest = jsonDecode(manifestFile.text!) as Map<String, dynamic>;
    expect(manifestFile.filename, 'chart_export_manifest.json');
    expect(manifestFile.mimeType, ChartExportManifest.mimeType);
    expect(manifestFile.metadata['createdAt'], '2026-06-05T00:00:00.000Z');
    expect(manifest['kind'], 'chartExportBatch');
    expect(manifest['createdAt'], '2026-06-05T00:00:00.000Z');
    expect((manifest['batch'] as Map<String, dynamic>)['successCount'], 2);

    final archiveFile = ChartExportArchive.exportBatchZip(
      batch,
      filename: 'batch_bundle',
      createdAt: DateTime.utc(2026, 6, 5),
    );
    expect(archiveFile.filename, 'batch_bundle.zip');
    expect(archiveFile.mimeType, ChartExportArchive.mimeType);
    expect(archiveFile.isBinary, isTrue);
    expect(archiveFile.metadata['kind'], 'chartExportArchive');
    expect(archiveFile.metadata['source'], 'exportBatch');
    expect(archiveFile.metadata['fileCount'], 3);
    final archiveText = latin1.decode(archiveFile.bytes);
    expect(archiveText, contains('batch.csv'));
    expect(archiveText, contains('batch.xlsx'));
    expect(archiveText, contains('manifest.json'));
    expect(archiveText, contains('chartExportBatch'));

    final partial = await ChartExporter.exportAll([
      ChartExportRequest.csv(
        config: config,
        categoryLabels: const ['A', 'B'],
        filename: 'mixed',
        lineEnding: '\n',
      ),
      const ChartExportRequest(
        format: ChartExportFormat.png,
        filename: 'mixed',
      ),
    ]);

    expect(partial.success, isFalse);
    expect(partial.hasFailures, isTrue);
    expect(partial.successCount, 1);
    expect(partial.failureCount, 1);
    expect(partial.successful.single.format, ChartExportFormat.csv);
    expect(partial.failed.single.format, ChartExportFormat.png);
    expect(partial.failed.single.filename, 'mixed.png');
    expect(
      partial.failed.single.error,
      contains('requires a repaint boundary key'),
    );
  });

  test('batch exports report progress and can stop on first failure', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );
    final progress = <ChartExportBatchProgress>[];

    final batch = await ChartExporter.exportAll(
      [
        ChartExportRequest.csv(
          config: config,
          categoryLabels: const ['A', 'B'],
          filename: 'progress',
          lineEnding: '\n',
        ),
        const ChartExportRequest(
          format: ChartExportFormat.png,
          filename: 'progress',
        ),
        ChartExportRequest.xlsx(
          config: config,
          categoryLabels: const ['A', 'B'],
          filename: 'progress',
        ),
      ],
      options: ChartExportBatchOptions(
        stopOnFirstFailure: true,
        onProgress: progress.add,
      ),
    );

    expect(batch.results, hasLength(2));
    expect(batch.success, isFalse);
    expect(batch.requestedCount, 3);
    expect(batch.successCount, 1);
    expect(batch.failureCount, 1);
    expect(batch.skippedUnavailableCount, 0);
    expect(batch.notRunCount, 1);
    expect(batch.hasIssues, isTrue);
    expect(batch.results.map((result) => result.format), [
      ChartExportFormat.csv,
      ChartExportFormat.png,
    ]);
    expect(progress.map((item) => item.completed), [1, 2]);
    expect(progress.map((item) => item.total), [3, 3]);
    expect(progress.last.isComplete, isFalse);
    expect(progress.last.remaining, 1);
    expect(progress.last.toMetadataJson()['fraction'], closeTo(2 / 3, 0.001));
    expect(batch.toMetadataJson()['notRunCount'], 1);
    expect(batch.issueMessages, hasLength(2));
    expect(batch.primaryIssue, contains('Export failed for progress.png'));
    expect(batch.issueMessages.last, '1 export not run.');
    expect(
      batch.toMetadataJson()['primaryIssue'],
      contains('Export failed for progress.png'),
    );
    expect(batch.summaryText(), '1 of 3 exports failed; 1 export not run');
  });

  test('batch export progress callback errors fail fast by default', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );
    var progressCalls = 0;

    await expectLater(
      ChartExporter.exportAll(
        [
          ChartExportRequest.csv(
            config: config,
            filename: 'progress_fail_fast',
          ),
          ChartExportRequest.xlsx(
            config: config,
            filename: 'progress_fail_fast',
          ),
        ],
        options: ChartExportBatchOptions(
          onProgress: (_) {
            progressCalls++;
            throw StateError('progress observer failed');
          },
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(progressCalls, 1);
  });

  test('batch export can continue after progress callback errors', () async {
    final config = _ExportTestConfig(
      series: [
        Series(type: ChartType.line, name: 'Sales', data: [10, 20]),
      ],
    );
    final progress = <ChartExportBatchProgress>[];
    final errors = <String>[];

    final batch = await ChartExporter.exportAll(
      [
        ChartExportRequest.csv(config: config, filename: 'progress_guard'),
        ChartExportRequest.xlsx(config: config, filename: 'progress_guard'),
      ],
      options: ChartExportBatchOptions(
        continueOnProgressError: true,
        onProgress: (item) {
          progress.add(item);
          if (item.completed == 1) {
            throw StateError('progress observer failed');
          }
        },
        onProgressError: (error, _, item) {
          errors.add('${item.completed}:$error');
        },
      ),
    );

    expect(batch.success, isTrue);
    expect(batch.successCount, 2);
    expect(progress.map((item) => item.completed), [1, 2]);
    expect(errors, hasLength(1));
    expect(errors.single, contains('progress observer failed'));
  });

  test('export results expose payload metadata helpers', () {
    final textResult = ChartExportResult.text(
      format: ChartExportFormat.csv,
      filename: 'sales.csv',
      text: 'A,B\n1,2',
    );

    expect(utf8.decode(textResult.payloadBytes!), 'A,B\n1,2');
    expect(textResult.base64Payload, base64Encode(utf8.encode('A,B\n1,2')));
    expect(
      textResult.dataUri,
      'data:text/csv;base64,${base64Encode(utf8.encode('A,B\n1,2'))}',
    );
    expect(textResult.contentDisposition(), 'attachment; filename="sales.csv"');
    expect(
      ChartExportResult.text(
        format: ChartExportFormat.csv,
        filename: 'sales "q".csv',
        text: 'x',
      ).contentDisposition(),
      'attachment; filename="sales \\"q\\".csv"',
    );
    expect(textResult.textPreview(maxChars: 3), 'A,B...');
    expect(textResult.preview(maxTextChars: 3), 'A,B...');
    expect(textResult.toMetadataJson(), {
      'success': true,
      'format': 'csv',
      'mimeType': ChartExporter.csvMimeType,
      'filename': 'sales.csv',
      'sizeBytes': 7,
      'isText': true,
      'isBinary': false,
    });
    expect(textResult.toMetadataJson(includePayload: true)['text'], 'A,B\n1,2');
    expect(
      textResult.toMetadataJson(includePayload: true)['base64'],
      textResult.base64Payload,
    );

    final binaryResult = ChartExportResult.bytes(
      format: ChartExportFormat.xlsx,
      filename: 'report.xlsx',
      bytes: Uint8List.fromList([0x50, 0x4b, 0x01]),
    );
    expect(binaryResult.payloadBytes, [0x50, 0x4b, 0x01]);
    expect(binaryResult.base64Payload, 'UEsB');
    expect(
      binaryResult.dataUri,
      'data:${ChartExporter.xlsxMimeType};base64,UEsB',
    );
    expect(binaryResult.byteSignature(), '50 4b 01');
    expect(binaryResult.preview(), 'bytes=3; signature=50 4b 01');

    final failure = ChartExportResult.failure(
      format: ChartExportFormat.csv,
      filename: 'bad.csv',
      error: 'No export payload.',
    );
    expect(failure.payloadBytes, isNull);
    expect(failure.dataUri, isNull);
    expect(failure.preview(), 'No export payload.');
    expect(failure.toMetadataJson()['error'], 'No export payload.');
  });

  test('exports raw payload rows for advanced chart shapes', () async {
    final treeRows = ChartExporter.rowsFromPayload(const {
      'type': 'treemap',
      'data': [
        {
          'name': 'Root',
          'value': 30,
          'children': [
            {'name': 'Leaf A', 'value': 10},
            {'name': 'Leaf B', 'value': 20},
          ],
        },
      ],
    });
    expect(treeRows.first, ['Path', 'Name', 'Parent', 'Depth', 'Value']);
    expect(treeRows[1], ['Root', 'Root', '', 0, 30]);
    expect(treeRows[2], ['Root / Leaf A', 'Leaf A', 'Root', 1, 10]);

    final flowRows = ChartExporter.rowsFromPayload(const {
      'type': 'sankey',
      'nodes': [
        {'id': 'a', 'name': 'A'},
        {'id': 'b', 'name': 'B'},
      ],
      'links': [
        {'source': 'a', 'target': 'b', 'value': 42},
      ],
    });
    expect(flowRows.first, ['Kind', 'Id', 'Name', 'Source', 'Target', 'Value']);
    expect(flowRows[3], ['link', '', '', 'a', 'b', 42]);

    final raceRows = ChartExporter.rowsFromPayload(const {
      'type': 'barRace',
      'categories': ['Alpha', 'Beta'],
      'frameLabels': ['2024', '2025'],
      'frames': [
        [10, 20],
        {
          'label': '2025',
          'values': {'Alpha': 12, 'Beta': 24},
        },
      ],
    });
    expect(raceRows.first, ['Frame', 'Category', 'Value']);
    expect(raceRows[1], ['2024', 'Alpha', 10]);
    expect(raceRows[4], ['2025', 'Beta', 24]);

    final result = await ChartExporter.export(
      ChartExportRequest.csvPayload(
        jsonConfig: const {
          'type': 'barRace',
          'frames': [
            {
              'label': 'Now',
              'values': {'A': 1},
            },
          ],
        },
        filename: 'race',
        lineEnding: '\n',
      ),
    );
    expect(result.success, isTrue);
    expect(result.filename, 'race.csv');
    expect(result.text, contains('Frame,Category,Value'));
    expect(result.text, contains('Now,A,1'));
  });

  testWidgets('captures chart widget as PNG and JPEG bytes', (tester) async {
    final controller = ExportableChartController();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ExportableChart(
            controller: controller,
            child: const SizedBox(
              width: 48,
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final png = await tester.runAsync(() => controller.capture(pixelRatio: 1));
    expect(png, isNotNull);
    expect(png!.take(8), [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

    final jpeg = await tester.runAsync(
      () => controller.captureJpeg(pixelRatio: 1, quality: 80),
    );
    expect(jpeg, isNotNull);
    expect(jpeg!.first, 0xff);
    expect(jpeg[1], 0xd8);
    expect(jpeg[jpeg.length - 2], 0xff);
    expect(jpeg.last, 0xd9);

    final genericJpeg = await tester.runAsync(
      () => controller.captureBytes(
        format: ChartImageExportFormat.jpeg,
        pixelRatio: 1,
        jpegQuality: 75,
      ),
    );
    expect(genericJpeg, isNotNull);
    expect(genericJpeg!.first, 0xff);
    expect(genericJpeg[1], 0xd8);

    final invalidPng = await tester.runAsync(
      () => controller.capture(pixelRatio: 0),
    );
    expect(invalidPng, isNull);

    final invalidImage = await tester.runAsync(
      () => controller.captureImage(pixelRatio: double.nan),
    );
    expect(invalidImage, isNull);
  });

  testWidgets('exports image bytes through unified request results', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 24,
              height: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.green),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pngResult = (await tester.runAsync(
      () => ChartExporter.export(
        ChartExportRequest.png(
          boundaryKey: key,
          filename: 'chart',
          pixelRatio: 1,
        ),
      ),
    ))!;
    expect(pngResult.success, isTrue);
    expect(pngResult.mimeType, ChartExporter.pngMimeType);
    expect(pngResult.filename, 'chart.png');
    expect(pngResult.bytes, isNotNull);
    expect(pngResult.bytes!.take(4), [0x89, 0x50, 0x4e, 0x47]);

    final jpegResult = (await tester.runAsync(
      () => ChartExporter.export(
        ChartExportRequest.jpeg(
          boundaryKey: key,
          filename: 'chart.jpg',
          pixelRatio: 1,
          jpegQuality: 70,
        ),
      ),
    ))!;
    expect(jpegResult.success, isTrue);
    expect(jpegResult.mimeType, ChartExporter.jpegMimeType);
    expect(jpegResult.filename, 'chart.jpg');
    expect(jpegResult.bytes, isNotNull);
    expect(jpegResult.bytes!.first, 0xff);
    expect(jpegResult.bytes![1], 0xd8);

    final batch = (await tester.runAsync(
      () => ChartExporter.exportFormats(
        formats: const [
          ChartExportFormat.csv,
          ChartExportFormat.png,
          ChartExportFormat.jpeg,
        ],
        rows: const [
          ['Category', 'Value'],
          ['A', 10],
        ],
        boundaryKey: key,
        filename: 'bundle',
        pixelRatio: 1,
        jpegQuality: 70,
      ),
    ))!;
    expect(batch.success, isTrue);
    expect(batch.successCount, 3);
    expect(batch.resultFor(ChartExportFormat.csv)?.text, contains('A,10'));
    expect(batch.resultFor(ChartExportFormat.png)?.bytes?.take(4), [
      0x89,
      0x50,
      0x4e,
      0x47,
    ]);
    expect(batch.resultFor(ChartExportFormat.jpeg)?.bytes?.take(2), [
      0xff,
      0xd8,
    ]);

    final failure = await ChartExporter.export(
      const ChartExportRequest(format: ChartExportFormat.png),
    );
    expect(failure.success, isFalse);
    expect(failure.error, contains('requires a repaint boundary key'));
  });
}

class _ExportTestConfig extends BaseChartConfig {
  _ExportTestConfig({required super.series}) : super(type: ChartType.line);

  @override
  Widget buildChart() => const SizedBox.shrink();
}
