import 'chart_export.dart';
import 'chart_export_delivery.dart';
import 'chart_export_filename.dart';
import 'chart_export_manifest.dart';
import 'chart_zip_store_writer.dart';

class ChartExportArchive {
  const ChartExportArchive._();

  static const String mimeType = 'application/zip';
  static const String defaultExportFilename = 'chart_export_bundle';
  static const String defaultDeliveryFilename = 'chart_delivery_bundle';
  static const String defaultManifestFilename = 'manifest';

  /// Bundle successful export results into a ZIP file.
  ///
  /// Failed export results are not written as payload files, but they remain
  /// visible in the optional manifest so callers can inspect partial failures.
  static ChartExportFile exportBatchZip(
    ChartExportBatchResult batch, {
    String filename = defaultExportFilename,
    bool includeManifest = true,
    String manifestFilename = defaultManifestFilename,
    DateTime? createdAt,
  }) {
    final files = <ChartExportFile>[];
    for (final result in batch.successful) {
      final file = ChartExportFile.tryFromResult(result);
      if (file != null) files.add(file);
    }

    if (includeManifest) {
      files.add(
        ChartExportManifest.exportBatchFile(
          batch,
          filename: manifestFilename,
          createdAt: createdAt,
        ),
      );
    }

    return filesZip(
      files,
      filename: filename,
      metadata: {
        'source': 'exportBatch',
        'sourceSuccess': batch.success,
        'sourceCount': batch.results.length,
        'sourceRequestedCount': batch.requestedCount,
        'sourceSuccessCount': batch.successCount,
        'sourceOutputCount': batch.outputCount,
        'sourceFailureCount': batch.failureCount,
        'sourceSkippedUnavailableCount': batch.skippedUnavailableCount,
        'sourceNotRunCount': batch.notRunCount,
        'sourceIssueCount': batch.issueCount,
        'sourceHasOutput': batch.hasOutput,
        'sourceHasIssues': batch.hasIssues,
        'sourceCompletedWithoutOutput': batch.completedWithoutOutput,
        'includedManifest': includeManifest,
      },
    );
  }

  /// Bundle successfully delivered files into a ZIP file.
  ///
  /// Failed delivery results are not written as payload files, but they remain
  /// visible in the optional manifest so callers can inspect partial failures.
  static ChartExportFile deliveryBatchZip(
    ChartExportDeliveryBatchResult batch, {
    String filename = defaultDeliveryFilename,
    bool includeManifest = true,
    String manifestFilename = defaultManifestFilename,
    DateTime? createdAt,
  }) {
    final files = <ChartExportFile>[...batch.files];

    if (includeManifest) {
      files.add(
        ChartExportManifest.deliveryBatchFile(
          batch,
          filename: manifestFilename,
          createdAt: createdAt,
        ),
      );
    }

    return filesZip(
      files,
      filename: filename,
      metadata: {
        'source': 'deliveryBatch',
        'sourceSuccess': batch.success,
        'sourceCount': batch.results.length,
        'sourceSuccessCount': batch.successCount,
        'sourceFailureCount': batch.failureCount,
        'includedManifest': includeManifest,
      },
    );
  }

  /// Bundle arbitrary export files into a ZIP file.
  static ChartExportFile filesZip(
    Iterable<ChartExportFile> files, {
    String filename = defaultExportFilename,
    Map<String, Object?> metadata = const {},
  }) {
    final resolvedFiles = files.toList(growable: false);
    final zipBytes = ChartZipStoreWriter.writeFiles(
      resolvedFiles.map(
        (file) => ChartZipStoreFile(name: file.filename, bytes: file.bytes),
      ),
    );
    final totalSourceSizeBytes = resolvedFiles.fold<int>(
      0,
      (total, file) => total + file.sizeBytes,
    );

    return ChartExportFile(
      filename: ChartExportFilename.withExtension(filename, 'zip'),
      mimeType: mimeType,
      bytes: zipBytes,
      metadata: {
        ...metadata,
        'kind': 'chartExportArchive',
        'schemaVersion': ChartExportManifest.schemaVersion,
        'fileCount': resolvedFiles.length,
        'totalSourceSizeBytes': totalSourceSizeBytes,
        'archiveSizeBytes': zipBytes.length,
        'files': [for (final file in resolvedFiles) file.toMetadataJson()],
      },
    );
  }
}
